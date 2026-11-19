#!/bin/sh
# Start the web tier: serves static files from ./public and proxies /api to the internal LB
cd /home/site/wwwroot || exit 1
export PORT="${PORT:-8080}"
exec node server.js