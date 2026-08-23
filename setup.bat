@echo off
setlocal
REM claudetldr setup - installs the invisible sync service (Windows).
REM Mirrors your Claude conversations to Documents\claude-sessions so the
REM viewer can connect once and reconnect automatically forever after.
REM No admin rights needed. Undo anytime with uninstall.bat.

set "INSTALL=%LOCALAPPDATA%\claudetldr"
mkdir "%INSTALL%" 2>nul

REM stop a running sync instance so upgrades replace the script cleanly
powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" | Where-Object { $_.CommandLine -like '*sync-service.ps1*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }" >nul 2>nul
copy /Y "%~dp0tools\sync-service.ps1" "%INSTALL%" >nul || goto :err
copy /Y "%~dp0tools\run-hidden.vbs"  "%INSTALL%" >nul || goto :err

reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "claudetldr-sync" /t REG_SZ /d "wscript.exe \"%INSTALL%\run-hidden.vbs\"" /f || goto :err
start "" wscript.exe "%INSTALL%\run-hidden.vbs"

echo.
echo   claudetldr sync installed and running (invisible).
echo.
echo   mirrors  %%APPDATA%%\Claude\local-agent-mode-sessions
echo   to       %%USERPROFILE%%\Downloads\claude-sessions   (every ~2 seconds)
echo.
echo   Last step, once: open the viewer, click "connect Cowork" and pick
echo   Downloads\claude-sessions. It reconnects by itself from then on.
echo.
pause
exit /b 0

:err
echo Setup failed - run this as your normal user (no admin needed) from the repo folder.
pause
exit /b 1
