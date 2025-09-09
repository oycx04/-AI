@echo off
chcp 65001 >nul
echo Starting AI Learning Assistant Servers...
echo.

echo [1/3] Starting Backend Server (Flask + PostgreSQL)...
start "Backend Server" cmd /k "cd /d f:\ai应用（1）\backend && python app.py"

echo [2/3] Waiting for backend initialization...
timeout /t 3 /nobreak >nul

echo [3/3] Starting Frontend Server (HTTP Server)...
start "Frontend Server" cmd /k "cd /d f:\ai应用（1）\frontend && python -m http.server 8000"

echo.
echo ✅ All servers are starting up!
echo.
echo 📱 Frontend: http://localhost:8000
echo 🔧 Backend:  http://localhost:5000
echo 🗄️  Database: PostgreSQL
echo.
echo Press any key to exit this window...
pause >nul