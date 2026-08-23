@echo off
setlocal
REM claudetldr setup - installs the invisible sync service (Windows).
REM Mirrors your Claude conversations to Documents\claude-sessions so the
REM viewer can connect once and reconnect automatically forever after.
REM No admin rights needed. Undo anytime with uninstall.bat.

set "INSTALL=%LOCALAPPDATA%\claudetldr"
mkdir "%INSTALL%" 2>nul
copy /Y "%~dp0tools\sync-service.ps1" "%INSTALL%" >nul || goto :err
copy /Y "%~dp0tools\run-hidden.vbs"  "%INSTALL%" >nul || goto :err

schtasks /Create /F /TN "claudetldr-sync" /SC ONLOGON /TR "wscript.exe \"%INSTALL%\run-hidden.vbs\"" >nul || goto :err
schtasks /Run /TN "claudetldr-sync" >nul 2>nul

echo.
echo   claudetldr sync installed and running (invisible).
echo.
echo   mirrors  %%APPDATA%%\Claude\local-agent-mode-sessions
echo   to       %%USERPROFILE%%\Documents\claude-sessions   (every ~2 seconds)
echo.
echo   Last step, once: open the viewer, click "connect Cowork" and pick
echo   Documents\claude-sessions. It reconnects by itself from then on.
echo.
pause
exit /b 0

:err
echo Setup failed - run this as your normal user (no admin needed) from the repo folder.
pause
exit /b 1
