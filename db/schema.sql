-- Create Candidates Table for UNN SUG Election
CREATE TABLE Candidates (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(100) NOT NULL,
    Department NVARCHAR(100) NOT NULL,
    VoteCount INT DEFAULT 0
);

-- Seed the 3 Candidates
INSERT INTO Candidates (Name, Department, VoteCount) VALUES 
('Comrd. Chinedu Okafor', 'Computer Science', 0),
('Comrd. Amarachi Eze', 'Law', 0),
('Comrd. Ibrahim Danladi', 'Pharmacy', 0);

-- Table to log individual votes to prevent double voting via Matric Number
CREATE TABLE VotesLog (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    VoterIdentifier NVARCHAR(255) UNIQUE NOT NULL,
    CandidateId INT FOREIGN KEY REFERENCES Candidates(Id),
    VotedAt DATETIME DEFAULT GETDATE()
);

-- Race-safe duplicate prevention (required by the API)
ALTER TABLE VotesLog ADD CONSTRAINT UQ_VoterIdentifier UNIQUE (VoterIdentifier);

-- Give the VMSS Managed Identity DB access
CREATE USER [demo-vmss] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [demo-vmss];
ALTER ROLE db_datawriter ADD MEMBER [demo-vmss];