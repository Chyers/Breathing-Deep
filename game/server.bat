@echo off
cd /d "%~dp0AI-Server"

echo Checking dependencies...
if not exist node_modules (
    echo Installing dependencies...
    npm install
)

echo Starting AI Server...
node server.js