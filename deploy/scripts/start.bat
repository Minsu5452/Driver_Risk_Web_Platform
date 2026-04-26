@echo off
chcp 65001 >nul 2>&1

:: ================================================================
::  NIA Platform - Start (always-clean + HTTP health check)
::
::  ontent:
::  - Previous "if already running, skip" logic has been REMOVED.
::  - We now stop any existing NIA processes first, then start fresh.
::  - Each service's HTTP endpoint is polled until it actually responds
::    before moving on. Browser only opens when ALL 3 services are ready.
::  - start.log under logs/ records every step for troubleshooting.
::
::  Windows encoding note:
::  - This file must stay ASCII-only.
::  - Installed location is fixed to C:\NIA-Platform (no korean/space path).
:: ================================================================

:: === Admin credentials (set BEFORE enabledelayedexpansion; password contains '!') ===
set "ADMIN_USERNAME=admin"
set "ADMIN_PASSWORD=change-me-in-prod"

:: === Encoding (defend against Windows cp949 default) ===
set "PYTHONIOENCODING=utf-8"
set "PYTHONUTF8=1"
set "LC_ALL=C.UTF-8"
set "LANG=C.UTF-8"

setlocal enabledelayedexpansion

set "NIA=%~dp0"
if "!NIA:~-1!"=="\" set "NIA=!NIA:~0,-1!"
if not exist "!NIA!\logs" mkdir "!NIA!\logs"
cd /d "!NIA!"

set "STARTLOG=!NIA!\logs\start.log"

>> "!STARTLOG!" echo.
>> "!STARTLOG!" echo =============================
>> "!STARTLOG!" echo  Start at %date% %time%
>> "!STARTLOG!" echo =============================

echo.
echo  ========================================
echo    NIA Platform - starting
echo  ========================================
echo.

:: ================================================================
::  Step 1/5 - Stop any existing NIA processes (clean start)
:: ================================================================
echo  [1/5] Stopping any existing NIA services...
>> "!STARTLOG!" echo  [1/5] Stop existing services

:: 1-a. Nginx graceful quit first (if running from our install)
if exist "!NIA!\nginx\nginx.exe" (
    pushd "!NIA!\nginx"
    "!NIA!\nginx\nginx.exe" -s quit >nul 2>&1
    popd
    timeout /t 2 /nobreak >nul
)

:: 1-b. Path-based kill - only processes running from THIS install dir,
::      so we don't touch unrelated java/python on the machine.
powershell -ExecutionPolicy Bypass -Command ^
  "Get-CimInstance Win32_Process -Filter \"Name='nginx.exe' OR Name='java.exe' OR Name='python.exe' OR Name='pythonw.exe'\" | Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith('!NIA!') } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }" >nul 2>&1

:: 1-c. Port-based fallback for 3000/8000/8080 (NIA-exclusive ports)
for /f "tokens=5" %%a in ('netstat -ano 2^>nul ^| findstr ":3000 " ^| findstr "LISTENING"') do taskkill /PID %%a /T /F >nul 2>&1
for /f "tokens=5" %%a in ('netstat -ano 2^>nul ^| findstr ":8000 " ^| findstr "LISTENING"') do taskkill /PID %%a /T /F >nul 2>&1
for /f "tokens=5" %%a in ('netstat -ano 2^>nul ^| findstr ":8080 " ^| findstr "LISTENING"') do taskkill /PID %%a /T /F >nul 2>&1

:: 1-d. Wait for ports to actually release (max ~20s)
set /a W=0
:wait_release
set "STILL=0"
netstat -ano 2>nul | findstr ":3000 " | findstr "LISTENING" >nul 2>&1
if !errorlevel! equ 0 set "STILL=1"
netstat -ano 2>nul | findstr ":8000 " | findstr "LISTENING" >nul 2>&1
if !errorlevel! equ 0 set "STILL=1"
netstat -ano 2>nul | findstr ":8080 " | findstr "LISTENING" >nul 2>&1
if !errorlevel! equ 0 set "STILL=1"
if "!STILL!"=="0" goto :release_done
set /a W+=1
if !W! gtr 10 goto :release_done
timeout /t 2 /nobreak >nul
goto :wait_release
:release_done
echo        Done (ports cleared)
>> "!STARTLOG!" echo        Ports cleared

:: ================================================================
::  Step 2/5 - Start AI Engine + wait until HTTP ready
:: ================================================================
echo  [2/5] Starting AI Engine (Python/FastAPI)...
>> "!STARTLOG!" echo  [2/5] Start AI Engine
powershell -ExecutionPolicy Bypass -Command ^
  "Start-Process -FilePath '!NIA!\python\python.exe' -ArgumentList '-m','uvicorn','src.main:app','--host','0.0.0.0','--port','8000' -WorkingDirectory '!NIA!\ai-engine' -WindowStyle Hidden -RedirectStandardOutput '!NIA!\logs\ai-engine.log' -RedirectStandardError '!NIA!\logs\ai-engine-error.log'"

echo        Waiting for AI Engine to respond on :8000 (first run may take 30-60s)...
set /a W=0
:wait_ai
set /a W+=1
if !W! gtr 90 goto :wait_ai_timeout
timeout /t 2 /nobreak >nul
powershell -ExecutionPolicy Bypass -Command ^
  "try { Invoke-WebRequest -Uri 'http://127.0.0.1:8000/docs' -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop | Out-Null; exit 0 } catch { if ($_.Exception.Response) { exit 0 } else { exit 1 } }" >nul 2>&1
if !errorlevel! neq 0 goto :wait_ai
echo        AI Engine ready (after !W! x 2s)
>> "!STARTLOG!" echo        AI Engine ready after !W!*2s
goto :start_backend

:wait_ai_timeout
echo.
echo  [WARNING] AI Engine did not respond in time.
echo            Check logs: !NIA!\logs\ai-engine-error.log
>> "!STARTLOG!" echo  [WARNING] AI Engine timeout (>180s)

:start_backend
:: ================================================================
::  Step 3/5 - Start Backend + wait until HTTP ready
:: ================================================================
echo  [3/5] Starting Backend (Spring Boot)...
>> "!STARTLOG!" echo  [3/5] Start Backend
powershell -ExecutionPolicy Bypass -Command ^
  "Start-Process -FilePath '!NIA!\jre\bin\java.exe' -ArgumentList '-Dfile.encoding=UTF-8','-Dsun.jnu.encoding=UTF-8','-Dspring.profiles.active=prod','-jar','!NIA!\backend\nia-platform.jar' -WorkingDirectory '!NIA!\backend' -WindowStyle Hidden -RedirectStandardOutput '!NIA!\logs\backend.log' -RedirectStandardError '!NIA!\logs\backend-error.log'"

echo        Waiting for Backend to respond on :8080...
set /a W=0
:wait_be
set /a W+=1
if !W! gtr 45 goto :wait_be_timeout
timeout /t 2 /nobreak >nul
powershell -ExecutionPolicy Bypass -Command ^
  "try { Invoke-WebRequest -Uri 'http://127.0.0.1:8080/' -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop | Out-Null; exit 0 } catch { if ($_.Exception.Response) { exit 0 } else { exit 1 } }" >nul 2>&1
if !errorlevel! neq 0 goto :wait_be
echo        Backend ready (after !W! x 2s)
>> "!STARTLOG!" echo        Backend ready after !W!*2s
goto :start_nginx

:wait_be_timeout
echo.
echo  [WARNING] Backend did not respond in time.
echo            Check logs: !NIA!\logs\backend-error.log
>> "!STARTLOG!" echo  [WARNING] Backend timeout (>90s)

:start_nginx
:: ================================================================
::  Step 4/5 - Start Nginx + wait until HTTP ready
:: ================================================================
echo  [4/5] Starting Nginx...
>> "!STARTLOG!" echo  [4/5] Start Nginx
pushd "!NIA!\nginx"
powershell -ExecutionPolicy Bypass -Command ^
  "Start-Process -FilePath '!NIA!\nginx\nginx.exe' -WorkingDirectory '!NIA!\nginx' -WindowStyle Hidden"
popd

echo        Waiting for Nginx on :3000...
set /a W=0
:wait_nx
set /a W+=1
if !W! gtr 20 goto :wait_nx_timeout
timeout /t 1 /nobreak >nul
powershell -ExecutionPolicy Bypass -Command ^
  "try { Invoke-WebRequest -Uri 'http://127.0.0.1:3000/' -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop | Out-Null; exit 0 } catch { if ($_.Exception.Response) { exit 0 } else { exit 1 } }" >nul 2>&1
if !errorlevel! neq 0 goto :wait_nx
echo        Nginx ready (after !W! x 1s)
>> "!STARTLOG!" echo        Nginx ready after !W!*1s
goto :open_browser

:wait_nx_timeout
echo.
echo  [WARNING] Nginx did not respond in time.
echo            Check logs: !NIA!\logs\nginx-error.log
>> "!STARTLOG!" echo  [WARNING] Nginx timeout (>20s)

:open_browser
:: ================================================================
::  Step 5/5 - Open browser (small safety margin)
:: ================================================================
echo  [5/5] All services ready. Opening browser...
>> "!STARTLOG!" echo  [5/5] Open browser
timeout /t 2 /nobreak >nul
start "" "http://localhost:3000"

echo.
echo  ========================================
echo    NIA Platform is running.
echo    http://localhost:3000
echo  ========================================
echo.
echo  You can close this window. Services will keep running.
timeout /t 5 /nobreak >nul
endlocal
