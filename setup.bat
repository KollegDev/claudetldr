@echo off
REM ===========================================================================
REM  claudetldr - install (Windows). Short on purpose: read it before running.
REM
REM  What this does, in full:
REM    1. downloads two files from the public repo into %LOCALAPPDATA%\claudetldr:
REM         tools/serve-service.ps1   (the local server, ~140 readable lines)
REM         index.html                (the viewer)
REM    2. adds ONE per-user autostart entry so it runs after each logon:
REM         HKCU\...\CurrentVersion\Run  ->  claudetldr
REM    3. starts it and opens http://127.0.0.1:7817/
REM
REM  It needs no admin rights, copies none of your conversations anywhere,
REM  listens on 127.0.0.1 only (unreachable from the network), and makes no
REM  outbound connection after the two downloads. uninstall.bat removes all
REM  of it. Prefer no install at all? Use run-once.bat instead.
REM
REM  Source of every line it runs: https://github.com/KollegDev/claudetldr
REM ===========================================================================

set "SRC=https://raw.githubusercontent.com/KollegDev/claudetldr/main"
set "DIR=%LOCALAPPDATA%\claudetldr"
mkdir "%DIR%" 2>nul

echo Downloading the viewer and the local server...
curl.exe -fsSL "%SRC%/tools/serve-service.ps1" -o "%DIR%\serve-service.ps1" || goto :err
curl.exe -fsSL "%SRC%/index.html"              -o "%DIR%\index.html"        || goto :err

REM stop a previous instance so this upgrade takes effect
powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" | Where-Object { $_.CommandLine -like '*serve-service.ps1*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }" >nul 2>nul

REM start hidden (no console window) at every logon
> "%DIR%\run-hidden.vbs" echo CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File ""%DIR%\serve-service.ps1""", 0, False
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "claudetldr" /t REG_SZ /d "wscript.exe \"%DIR%\run-hidden.vbs\"" /f >nul || goto :err
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "claudetldr-sync" /f >nul 2>nul

start "" wscript.exe "%DIR%\run-hidden.vbs"
powershell -NoProfile -Command "Start-Sleep -Milliseconds 1500" >nul
start "" "http://127.0.0.1:7817/"

echo.
echo   Done - your conversations should be opening in the browser now.
echo   Bookmark http://127.0.0.1:7817/  (starts by itself after every logon)
echo   Remove it anytime with uninstall.bat
echo.
pause
exit /b 0

:err
echo.
echo   Setup failed - are you online? Run as your normal user (no admin needed).
pause
exit /b 1
