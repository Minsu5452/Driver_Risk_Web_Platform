@echo off
chcp 65001 >nul 2>&1

:: ================================================================
::  NIA Platform - Install (clean reinstall, every time)
::  1) End auto-start task  2) Kill running NIA processes (path-based)
::  3) Wipe C:\NIA-Platform (retry 5x)  4) Copy fresh files
::  5) Setup Python  6) Install wheels offline  7) Firewall / shortcuts
::  8) Register auto-start  9) Launch start.bat
:: ================================================================

:: ---- Admin check ----
net session >nul 2>&1
if %errorlevel% equ 0 goto :admin_ok
echo.
echo  [ERROR] Please right-click this file and select 'Run as administrator'.
echo.
pause
exit /b 1

:admin_ok
setlocal enabledelayedexpansion
set "SRC=%~dp0"
if "!SRC:~-1!"=="\" set "SRC=!SRC:~0,-1!"
set "NIA=C:\NIA-Platform"
cd /d "!SRC!"

:: ---- install log (persists even if cmd window dies mid-run) ----
set "INSTALLLOG=%USERPROFILE%\NIA-install.log"
>> "!INSTALLLOG!" echo.
>> "!INSTALLLOG!" echo =========================================
>> "!INSTALLLOG!" echo  Install at %date% %time%
>> "!INSTALLLOG!" echo  SRC=!SRC!
>> "!INSTALLLOG!" echo  NIA=!NIA!
>> "!INSTALLLOG!" echo =========================================

echo.
echo  ========================================
echo    NIA Platform Install
echo    Source: !SRC!
echo    Target: !NIA!
echo  ========================================
echo.

:: =================================================================
::  CRITICAL SAFETY CHECK — prevent installer from deleting itself
::
::  Step C does `rmdir /s /q C:\NIA-Platform`.  If install.bat
::  itself is located INSIDE C:\NIA-Platform (user extracted the
::  new zip into the old install dir, either on purpose or by
::  mistake), rmdir deletes install.bat while cmd.exe is still
::  reading it, and Windows silently terminates the terminal with
::  no error message.  This is the "terminal suddenly closed"
::  symptom.  Detect and refuse.
:: =================================================================

:: Case 1: SRC is exactly NIA
if /i "!SRC!"=="!NIA!" (
    echo.
    echo  [FATAL] install.bat is running FROM the target directory:
    echo          !NIA!
    echo          Step C would wipe !NIA! and delete install.bat itself,
    echo          which closes this window with no warning.
    echo.
    echo  [FIX]   Move the zip to a different location, extract, and run
    echo          install.bat from there.  Good examples:
    echo              D:\temp\NIA-Platform-AutoStart\install.bat
    echo              C:\install\NIA-Platform-AutoStart\install.bat
    echo.
    >> "!INSTALLLOG!" echo  [FATAL] SRC == NIA. Refusing to self-delete.
    pause
    exit /b 1
)

:: Case 2: SRC is inside NIA (sub-directory of NIA)
set "NIA_WITH_SLASH=!NIA!\"
echo !SRC!\| findstr /i /b /c:"!NIA_WITH_SLASH!" >nul
if !errorlevel! equ 0 (
    echo.
    echo  [FATAL] install.bat is inside the target directory !NIA!:
    echo          Current location: !SRC!
    echo          Step C would wipe !NIA! and delete install.bat itself,
    echo          which closes this window with no warning.
    echo.
    echo  [FIX]   Move the zip to a different location, extract, and run
    echo          install.bat from there.  Good examples:
    echo              D:\temp\NIA-Platform-AutoStart\install.bat
    echo              C:\install\NIA-Platform-AutoStart\install.bat
    echo.
    >> "!INSTALLLOG!" echo  [FATAL] SRC inside NIA. SRC=!SRC! NIA=!NIA!
    pause
    exit /b 1
)
>> "!INSTALLLOG!" echo  Safety check passed

:: ---- Step A: Remove existing auto-start task ----
echo  [A] Removing old auto-start task (if any)...
>> "!INSTALLLOG!" echo  [A] Remove auto-start task
schtasks /End    /TN "NIA_Platform" >nul 2>&1
schtasks /Delete /TN "NIA_Platform" /F >nul 2>&1
echo        Done
>> "!INSTALLLOG!" echo  [A] Done

:: ---- Step B: Kill NIA processes (path-based; safe for unrelated java/python) ----
echo  [B] Stopping existing NIA services...
>> "!INSTALLLOG!" echo  [B] Stop services

:: B-1. Nginx graceful quit (if installed at target)
if exist "!NIA!\nginx\nginx.exe" (
    pushd "!NIA!\nginx"
    "!NIA!\nginx\nginx.exe" -s quit >nul 2>&1
    popd
    timeout /t 2 /nobreak >nul
)

:: B-2. Path-based kill under C:\NIA-Platform (PowerShell)
powershell -ExecutionPolicy Bypass -Command ^
  "Get-CimInstance Win32_Process -Filter \"Name='nginx.exe' OR Name='java.exe' OR Name='python.exe' OR Name='pythonw.exe'\" | Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith('!NIA!') } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }" >nul 2>&1

:: B-3. Port-based fallback (3000/8000/8080 are NIA-exclusive)
for /f "tokens=5" %%a in ('netstat -ano 2^>nul ^| findstr ":3000 " ^| findstr "LISTENING"') do taskkill /PID %%a /T /F >nul 2>&1
for /f "tokens=5" %%a in ('netstat -ano 2^>nul ^| findstr ":8000 " ^| findstr "LISTENING"') do taskkill /PID %%a /T /F >nul 2>&1
for /f "tokens=5" %%a in ('netstat -ano 2^>nul ^| findstr ":8080 " ^| findstr "LISTENING"') do taskkill /PID %%a /T /F >nul 2>&1

:: B-4. Wait for ports to clear (up to 30s)
echo        Waiting for processes to exit...
set /a WAIT=0
:wait_proc
set "STILL=0"
netstat -ano 2>nul | findstr ":3000 " | findstr "LISTENING" >nul 2>&1
if !errorlevel! equ 0 set "STILL=1"
netstat -ano 2>nul | findstr ":8000 " | findstr "LISTENING" >nul 2>&1
if !errorlevel! equ 0 set "STILL=1"
netstat -ano 2>nul | findstr ":8080 " | findstr "LISTENING" >nul 2>&1
if !errorlevel! equ 0 set "STILL=1"
if "!STILL!"=="0" goto :proc_done
set /a WAIT+=1
if !WAIT! gtr 15 goto :proc_done
timeout /t 2 /nobreak >nul
goto :wait_proc
:proc_done
echo        Done
>> "!INSTALLLOG!" echo  [B] Done

:: ---- Step C: Wipe old installation (retry with increasing delay) ----
:: Note: SRC==NIA was already refused at the top safety check, so the
::       old `if /i "!SRC!"=="!NIA!" goto :skip_wipe` escape hatch is
::       no longer reachable - kept as a harmless no-op would also work,
::       but we omit it since the invariant holds from the safety check.
:: -------------------------------------------------------------------
::  Step C — existing-install check ONLY (no automatic deletion)
::
::  Why no auto-delete:
::    Earlier versions (v1.0.2 - v1.0.5) tried rmdir / Remove-Item /
::    rename to clear the old C:\NIA-Platform. Every approach was
::    silently killed by restrictive corporate AV on the target PC,
::    which treats bulk file operations against a 1.5GB install tree
::    as ransomware-like activity and terminates cmd.exe without
::    any error. We give up trying to outsmart the AV and instead
::    require the operator to delete the old folder manually
::    through Windows Explorer (which uses the shell API and is
::    whitelisted by AV as a normal user action).
:: -------------------------------------------------------------------
echo  [C] Checking for old installation...
>> "!INSTALLLOG!" echo  [C] Check !NIA!

if not exist "!NIA!" (
    echo        No old installation - proceed.
    >> "!INSTALLLOG!" echo  [C] No old install
    goto :do_copy
)

echo.
echo  ========================================================
echo   An existing installation was detected at:
echo     !NIA!
echo.
echo   Automatic deletion has been disabled because aggressive
echo   anti-virus software on this PC may block batch-driven
echo   mass-delete operations.
echo.
echo   Please remove the old installation MANUALLY:
echo.
echo     1^) Open Windows Explorer
echo     2^) Go to  C:\
echo     3^) Right-click the "NIA-Platform" folder
echo     4^) Click "Delete"  ^(or Shift+Delete to skip the recycle bin^)
echo     5^) Wait until the deletion completes
echo     6^) Run install.bat again
echo.
echo  ========================================================
echo.
>> "!INSTALLLOG!" echo  [C] STOP - old install present, ask user to delete manually
pause
exit /b 2

:do_copy
:: ---- Step D: Copy fresh files ----
echo  [D] Copying fresh files (takes a minute - ~1.5GB)...
>> "!INSTALLLOG!" echo  [D] robocopy !SRC! -^> !NIA!
mkdir "!NIA!" >nul 2>&1
:: Use robocopy (built-in since Vista). More robust than xcopy for large
:: trees, better AV-friendly, clearer exit codes. Exit 0-7 are success.
robocopy "!SRC!" "!NIA!" /E /NFL /NDL /NJH /NJS /NP /R:1 /W:1 >nul 2>&1
if !errorlevel! gtr 7 goto :copy_fail
echo        Done
>> "!INSTALLLOG!" echo  [D] Done (robocopy rc=!errorlevel!)
goto :skip_wipe

:copy_fail
echo.
echo  [ERROR] Copy failed. Check disk space and permissions.
pause
exit /b 1

:skip_wipe
echo  Install path: !NIA!

:: ---- Step E: Python embeddable setup ----
echo  [E] Python setup...
if not exist "!NIA!\python\python310._pth" goto :no_python

:: Enable 'import site' (required for pip) - idempotent
powershell -ExecutionPolicy Bypass -Command ^
  "$pth='!NIA!\python\python310._pth'; $c=(Get-Content $pth) -replace '#import site','import site'; Set-Content -Path $pth -Value $c -Encoding ASCII"

:: Ensure ai-engine is importable. Append if not already present.
findstr /c:"ai-engine" "!NIA!\python\python310._pth" >nul 2>&1
if !errorlevel! neq 0 echo C:\NIA-Platform\ai-engine>>"!NIA!\python\python310._pth"
echo        Done
goto :step_pip

:no_python
echo.
echo  [ERROR] Python not found at: !NIA!\python\python310._pth
echo          The package is corrupted. Please re-obtain the zip.
pause
exit /b 1

:: ---- Step F: pip (offline) ----
:step_pip
echo  [F] Installing pip (offline)...
if not exist "!NIA!\logs" mkdir "!NIA!\logs"
set "PYTHONIOENCODING=utf-8"
set "PYTHONUTF8=1"
"!NIA!\python\python.exe" "!NIA!\python\get-pip.py" --no-index --find-links "!NIA!\wheels" > "!NIA!\logs\install-pip.log" 2>&1
if !errorlevel! neq 0 goto :pip_fail
echo        Done
goto :step_pkg

:pip_fail
echo.
echo  [ERROR] pip install failed.
echo          See: C:\NIA-Platform\logs\install-pip.log
pause
exit /b 1

:: ---- Step G: AI Engine packages (offline) ----
:step_pkg
echo  [G] Installing AI Engine packages (offline, 1-2 min)...
"!NIA!\python\python.exe" -m pip install --no-index --find-links "!NIA!\wheels" -r "!NIA!\ai-engine\requirements.txt" > "!NIA!\logs\install-packages.log" 2>&1
if !errorlevel! neq 0 goto :pkg_fail
echo        Done
goto :step_system

:pkg_fail
echo.
echo  [ERROR] Package install failed.
echo          See: C:\NIA-Platform\logs\install-packages.log
pause
exit /b 1

:: ---- Step H: Firewall / Shortcuts / Auto-start ----
:step_system
echo  [H] Firewall + Shortcuts + Auto-start + admin.conf...
>> "!INSTALLLOG!" echo  [H] Firewall+Shortcuts+Auto-start+admin.conf

:: ---- Admin credentials file ----
:: Write admin.conf with DELAYED EXPANSION DISABLED so '!' in password
:: stays literal (otherwise cmd eats trailing '!'). This is the canonical
:: source of ADMIN_USERNAME/ADMIN_PASSWORD for ai-engine; env vars in
:: start.bat are a secondary fallback.
setlocal DisableDelayedExpansion
(
    echo # NIA Platform admin credentials
    echo # This file is generated by install.bat. Edit with care.
    echo username=admin
    echo password=change-me-in-prod
) > "C:\NIA-Platform\admin.conf"
endlocal
echo        admin.conf written

:: Firewall rule (replace if exists)
netsh advfirewall firewall delete rule name="NIA Platform" >nul 2>&1
netsh advfirewall firewall add rule name="NIA Platform" dir=in action=allow protocol=TCP localport=3000,8000,8080 >nul 2>&1

:: Desktop shortcuts (replace)
set "DT=!USERPROFILE!\Desktop"
if exist "!DT!\NIA Start.lnk"    del /f /q "!DT!\NIA Start.lnk"    >nul 2>&1
if exist "!DT!\NIA Stop.lnk"     del /f /q "!DT!\NIA Stop.lnk"     >nul 2>&1
if exist "!DT!\NIA Platform.lnk" del /f /q "!DT!\NIA Platform.lnk" >nul 2>&1

powershell -ExecutionPolicy Bypass -Command ^
  "$w=New-Object -ComObject WScript.Shell;$s=$w.CreateShortcut('!DT!\NIA Start.lnk');$s.TargetPath='!NIA!\start.bat';$s.WorkingDirectory='!NIA!';$s.IconLocation='shell32.dll,21';$s.Save()"
powershell -ExecutionPolicy Bypass -Command ^
  "$w=New-Object -ComObject WScript.Shell;$s=$w.CreateShortcut('!DT!\NIA Stop.lnk');$s.TargetPath='!NIA!\stop.bat';$s.WorkingDirectory='!NIA!';$s.IconLocation='shell32.dll,27';$s.Save()"
powershell -ExecutionPolicy Bypass -Command ^
  "$w=New-Object -ComObject WScript.Shell;$s=$w.CreateShortcut('!DT!\NIA Platform.lnk');$s.TargetPath='http://localhost:3000';$s.IconLocation='shell32.dll,14';$s.Save()"

:: Auto-start on logon with 60s delay (required: avoids login-peak resource
:: contention that caused AI Engine to fail first-run during ONLOGON trigger).
::
:: schtasks command-line doesn't support /DELAY for /SC ONLOGON, so we import
:: an XML definition. schtasks requires UTF-16 encoded XML -> convert our
:: UTF-8 bundled template on the fly via PowerShell.
schtasks /Delete /TN "NIA_Platform" /F >nul 2>&1
if exist "!NIA!\autostart-task.xml" (
    powershell -ExecutionPolicy Bypass -Command ^
      "Get-Content '!NIA!\autostart-task.xml' -Raw -Encoding UTF8 | Out-File -FilePath '%TEMP%\nia_task.xml' -Encoding Unicode" >nul 2>&1
    schtasks /Create /TN "NIA_Platform" /XML "%TEMP%\nia_task.xml" /F >nul 2>&1
    if !errorlevel! neq 0 (
        echo        [WARN] XML-based task register failed, falling back to immediate ONLOGON
        schtasks /Create /TN "NIA_Platform" /TR "\"!NIA!\start.bat\"" /SC ONLOGON /RL HIGHEST /F >nul 2>&1
    )
    del /f /q "%TEMP%\nia_task.xml" >nul 2>&1
) else (
    echo        [WARN] autostart-task.xml missing - using immediate ONLOGON
    schtasks /Create /TN "NIA_Platform" /TR "\"!NIA!\start.bat\"" /SC ONLOGON /RL HIGHEST /F >nul 2>&1
)
echo        Done (auto-start: logon + 60s delay)

echo.
echo  ========================================
echo    Installation complete.
echo    Starting services...
echo  ========================================
echo.

:: ---- Step I: Launch ----
>> "!INSTALLLOG!" echo  [I] Launch start.bat
call "!NIA!\start.bat"
>> "!INSTALLLOG!" echo  [I] start.bat returned

echo.
echo  Press any key to close this window. Services will keep running.
>> "!INSTALLLOG!" echo  Install complete at %date% %time%
pause >nul
endlocal
