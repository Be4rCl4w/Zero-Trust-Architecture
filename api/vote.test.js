const test = require('node:test');
const assert = require('node:assert/strict');
const Module = require('module');

// ---------------------------------------------------------------------------
// In-memory fakes for 'mssql' and '@azure/identity', injected before the app
// is required, so the suite runs against a realistic DB without Azure SQL.
// ---------------------------------------------------------------------------

const state = {
    candidates: [],
    votes: [],
    failNextInsertWith: null,
    rollbacks: 0,
};

const BASELINE_CANDIDATES = [
    { Id: 1, Name: 'Ada Okafor', Department: 'Computer Science', VoteCount: 5 },
    { Id: 2, Name: 'Emeka Obi', Department: 'Economics', VoteCount: 3 },
];

function resetState() {
    state.candidates = BASELINE_CANDIDATES.map((c) => ({ ...c }));
    state.votes = [];
    state.failNextInsertWith = null;
    state.rollbacks = 0;
}

function createRequest() {
    return {
        inputs: {},
        input(name, type, value) {
            this.inputs[name] = value;
            return this;
        },
        async query(text) {
            // SELECT Id FROM Candidates WHERE Id = @candidateId
            if (text.includes('FROM Candidates WHERE Id')) {
                return {
                    recordset: state.candidates
                        .filter((c) => c.Id === this.inputs.candidateId)
                        .map((c) => ({ Id: c.Id })),
                };
            }
            // SELECT Id, Name, Department, VoteCount FROM Candidates
            if (text.includes('FROM Candidates')) {
                return { recordset: state.candidates.map((c) => ({ ...c })) };
            }
            // SELECT Id FROM VotesLog WHERE VoterIdentifier = @voterId
            if (text.includes('FROM VotesLog')) {
                return {
                    recordset: state.votes
                        .filter((v) => v.VoterIdentifier === this.inputs.voterId)
                        .map((v) => ({ Id: v.Id })),
                };
            }
            // INSERT INTO VotesLog ...
            if (text.includes('INSERT INTO VotesLog')) {
                if (state.failNextInsertWith) {
                    const err = state.failNextInsertWith;
                    state.failNextInsertWith = null;
                    throw err;
                }
                // Emulate the UNIQUE constraint on VoterIdentifier at the schema level
                if (state.votes.some((v) => v.VoterIdentifier === this.inputs.voterId)) {
                    const err = new Error('Violation of UNIQUE KEY constraint');
                    err.number = 2627;
                    throw err;
                }
                state.votes.push({
                    Id: state.votes.length + 1,
                    VoterIdentifier: this.inputs.voterId,
                    CandidateId: this.inputs.candidateId,
                });
                return { recordset: [], rowsAffected: [1] };
            }
            // UPDATE Candidates SET VoteCount = VoteCount + 1 WHERE Id = @candidateId
            if (text.includes('UPDATE Candidates')) {
                const cand = state.candidates.find((c) => c.Id === this.inputs.candidateId);
                if (cand) cand.VoteCount += 1;
                return { recordset: [], rowsAffected: [cand ? 1 : 0] };
            }
            // SELECT 1 (health probe)
            if (text.trim() === 'SELECT 1') {
                return { recordset: [{ ok: 1 }] };
            }
            throw new Error(`Unexpected query in fake mssql: ${text}`);
        },
    };
}

const fakeMssql = {
    NVarChar: 'nvarchar',
    Int: 'int',
    async connect() {
        const pool = { request: createRequest, on: () => {} };
        return pool;
    },
    Transaction: class {
        constructor() {}
        async begin() {}
        async commit() {}
        async rollback() {
            state.rollbacks += 1;
        }
    },
    Request: class {
        constructor() {
            return createRequest();
        }
    },
};

class FakeDefaultAzureCredential {
    async getToken() {
        return { token: 'fake-managed-identity-token', expiresOnTimestamp: Date.now() + 3600_000 };
    }
}

// Intercept module resolution BEFORE the app is loaded
const originalLoad = Module._load;
Module._load = function (request, parent, isMain) {
    if (request === 'mssql') return fakeMssql;
    if (request === '@azure/identity') return { DefaultAzureCredential: FakeDefaultAzureCredential };
    return originalLoad.apply(this, arguments);
};

const request = require('supertest');
const { app } = require('../server.js');

// ---------------------------------------------------------------------------

test.beforeEach(resetState);

test('GET /api/health returns healthy status', async () => {
    const res = await request(app).get('/api/health').expect(200);
    assert.equal(res.body.status, 'Healthy');
    assert.equal(res.body.institution, 'University of Nigeria, Nsukka');
});

test('GET /api/candidates returns all candidates with vote counts', async () => {
    const res = await request(app).get('/api/candidates').expect(200);
    assert.equal(res.body.length, 2);
    assert.deepEqual(
        res.body.map((c) => c.Name),
        ['Ada Okafor', 'Emeka Obi']
    );
    assert.equal(res.body[0].VoteCount, 5);
});

test('POST /api/vote records a vote and increments the candidate tally', async () => {
    const res = await request(app)
        .post('/api/vote')
        .send({ voterId: '2023/123456', candidateId: 1 })
        .expect(200);
    assert.match(res.body.message, /successfully recorded/i);

    const tally = await request(app).get('/api/candidates').expect(200);
    const ada = tally.body.find((c) => c.Id === 1);
    assert.equal(ada.VoteCount, 6);
    assert.equal(state.votes.length, 1);
});

test('POST /api/vote rejects a duplicate voter (application-level check)', async () => {
    await request(app).post('/api/vote').send({ voterId: '2023/123456', candidateId: 1 }).expect(200);

    const res = await request(app)
        .post('/api/vote')
        .send({ voterId: '2023/123456', candidateId: 2 })
        .expect(403);
    assert.match(res.body.error, /already recorded a vote/i);

    // Tally unchanged: second vote must not count
    const tally = await request(app).get('/api/candidates').expect(200);
    assert.equal(tally.body.find((c) => c.Id === 2).VoteCount, 3);
});

test('POST /api/vote maps unique-constraint violation to 403 (schema-level race guard)', async () => {
    // Simulate a concurrent request losing the race at the DB constraint
    state.failNextInsertWith = Object.assign(new Error('Violation of UNIQUE KEY constraint'), { number: 2627 });

    const res = await request(app)
        .post('/api/vote')
        .send({ voterId: '2023/999999', candidateId: 1 })
        .expect(403);
    assert.match(res.body.error, /already recorded a vote/i);

    // Transaction was rolled back and no phantom tally was added
    assert.equal(state.rollbacks, 1);
    const tally = await request(app).get('/api/candidates').expect(200);
    assert.equal(tally.body.find((c) => c.Id === 1).VoteCount, 5);
});

test('POST /api/vote returns 400 when fields are missing', async () => {
    await request(app).post('/api/vote').send({}).expect(400);
    await request(app).post('/api/vote').send({ voterId: '2023/123456' }).expect(400);
    await request(app).post('/api/vote').send({ candidateId: 1 }).expect(400);
});

test('POST /api/vote returns 400 for a non-integer candidateId', async () => {
    await request(app).post('/api/vote').send({ voterId: '2023/123456', candidateId: 'abc' }).expect(400);
    await request(app).post('/api/vote').send({ voterId: '2023/123456', candidateId: -1 }).expect(400);
    await request(app).post('/api/vote').send({ voterId: '2023/123456', candidateId: 1.5 }).expect(400);
});

test('POST /api/vote returns 400 for an unknown candidate and logs nothing', async () => {
    const res = await request(app)
        .post('/api/vote')
        .send({ voterId: '2023/123456', candidateId: 999 })
        .expect(400);
    assert.match(res.body.error, /invalid candidate/i);
    assert.equal(state.votes.length, 0);
});

test('POST /api/vote rolls back the transaction on an unexpected DB error', async () => {
    state.failNextInsertWith = new Error('simulated SQL connection failure');

    const res = await request(app)
        .post('/api/vote')
        .send({ voterId: '2023/123456', candidateId: 1 })
        .expect(500);
    assert.match(res.body.error, /internal server error/i);

    assert.equal(state.rollbacks, 1);
    const tally = await request(app).get('/api/candidates').expect(200);
    assert.equal(tally.body.find((c) => c.Id === 1).VoteCount, 5);
    assert.equal(state.votes.length, 0);
});