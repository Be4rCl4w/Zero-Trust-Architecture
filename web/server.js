require('dotenv').config();
const express = require('express');
const path = require('path');
const { createProxyMiddleware } = require('http-proxy-middleware');

// Fail fast: don't start with a missing backend target
if (!process.env.BACKEND_API_URL) {
    throw new Error('BACKEND_API_URL is not set');
}

const app = express();

// Health endpoint for the App Gateway probe and App Service health check
app.get('/healthz', (req, res) => res.status(200).send('ok'));

// Proxy /api to the internal load balancer.
// Mounted WITHOUT a path so Express doesn't strip "/api"; pathFilter selects what to proxy.
// IMPORTANT: no body parsers before this, or POST bodies are lost.
app.use(createProxyMiddleware({
    pathFilter: '/api',
    target: process.env.BACKEND_API_URL, 
    changeOrigin: true,
    proxyTimeout: 10000,
    timeout: 10000,
    on: {
        error: (err, req, res) => {
            console.error('Proxy error reaching API backend tier:', err.message);
            if (res.writeHead && !res.headersSent) {
                res.writeHead(502, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: 'Bad Gateway: Unable to reach backend API server.' }));
            }
        }
    }
}));

// Serve only index.html (no express.static on this folder, which also holds server.js, .env, etc.)
app.use((req, res) => {
    if (req.method !== 'GET') return res.sendStatus(404);
    res.sendFile(path.join(__dirname, 'index.html'));
});

const port = process.env.PORT || 3000;

if (require.main === module) {
    app.listen(port, () => {
        console.log(`Web Tier Proxy running on port ${port}`);
    });
}

module.exports = { app };