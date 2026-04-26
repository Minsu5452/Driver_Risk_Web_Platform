@echo off
chcp 65001 >nul 2>&1

:: ================================================================
::  NIA Platform - Stop
::  Gracefully stops nginx, then force-kills listeners on 8080/8000.
::  Use PowerShell path filter to avoid killing unrelated java/python.
:: ================================================================

setlocal enabledelayedexpansion

set "NIA=%~dp0"
if "!NIA:~-1!"=="\" set "NIA=!NIA:~0,-1!"
cd /d "!NIA!"

echo.
echo  Stopping NIA Platform...
echo.

:: ---- 1. Nginx (graceful quit, then forceful cleanup) ----
echo  [1/3] Nginx...
if exist "!NIA!\nginx\nginx.exe" (
    pushd "!NIA!\nginx"
    "!NIA!\nginx\nginx.exe" -s quit >nul 2>&1
    popd
    timeout /t 2 /nobreak >nul
)
:: Fallback: kill any remaining nginx.exe under our install path
powershell -ExecutionPolicy Bypass -Command ^
  "Get-CimInstance Win32_Process -Filter \"Name='nginx.exe'\" | Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith('!NIA!') } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }" >nul 2>&1

:: ---- 2. Backend (port 8080) ----
echo  [2/3] Backend...
for /f "tokens=5" %%a in ('netstat -ano 2^>nul ^| findstr ":8080 " ^| findstr "LISTENING"') do (
    taskkill /PID %%a /T /F >nul 2>&1
)

:: ---- 3. AI Engine (port 8000) ----
echo  [3/3] AI Engine...
for /f "tokens=5" %%a in ('netstat -ano 2^>nul ^| findstr ":8000 " ^| findstr "LISTENING"') do (
    taskkill /PID %%a /T /F >nul 2>&1
)

:: Final defensive sweep: kill java/python processes running from our install dir
powershell -ExecutionPolicy Bypass -Command ^
  "Get-CimInstance Win32_Process -Filter \"Name='java.exe' OR Name='python.exe' OR Name='pythonw.exe'\" | Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith('!NIA!') } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }" >nul 2>&1

echo.
echo  ========================================
echo    NIA Platform stopped.
echo  ========================================
echo.
timeout /t 3 /nobreak >nul
endlocal
