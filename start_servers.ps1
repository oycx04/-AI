# AI Learning Assistant Server Startup Script
# PowerShell version to avoid encoding issues

Write-Host "Starting AI Learning Assistant Servers..." -ForegroundColor Green
Write-Host ""

Write-Host "[1/3] Starting Backend Server (Flask + PostgreSQL)..." -ForegroundColor Yellow
Start-Process -FilePath "cmd" -ArgumentList "/k", "cd /d f:\ai应用（1）\backend && python app.py" -WindowStyle Normal

Write-Host "[2/3] Waiting for backend initialization..." -ForegroundColor Yellow
Start-Sleep -Seconds 3

Write-Host "[3/3] Starting Frontend Server (HTTP Server)..." -ForegroundColor Yellow
Start-Process -FilePath "cmd" -ArgumentList "/k", "cd /d f:\ai应用（1）\frontend && python -m http.server 8000" -WindowStyle Normal

Write-Host ""
Write-Host "All servers are starting up!" -ForegroundColor Green
Write-Host ""
Write-Host "Frontend: http://localhost:8000" -ForegroundColor Cyan
Write-Host "Backend:  http://localhost:5000" -ForegroundColor Cyan
Write-Host "Database: PostgreSQL" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press any key to exit this window..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")