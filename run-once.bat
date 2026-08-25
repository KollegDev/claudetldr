@echo off
REM ===========================================================================
REM  claudetldr - PORTABLE start. Nothing is installed, nothing is remembered.
REM
REM  What this does, in full:
REM    1. downloads two files from the public repo into a temp folder:
REM         tools/serve-service.ps1   (the local server, ~140 readable lines)
REM         index.html                (the viewer)
REM    2. opens http://127.0.0.1:7817/ in your browser
REM    3. runs the server in THIS window until you close it
REM
REM  It does not write to the registry, does not start with Windows, needs no
REM  admin rights, and makes no outbound connection after the two downloads.
REM  Close this window and everything stops. Delete %TEMP%\claudetldr to erase.
REM
REM  Source of every line it runs: https://github.com/KollegDev/claudetldr
REM ===========================================================================

set "SRC=https://raw.githubusercontent.com/KollegDev/claudetldr/main"
set "DIR=%TEMP%\claudetldr"
mkdir "%DIR%" 2>nul

echo Downloading the viewer and the local server...
curl.exe -fsSL "%SRC%/tools/serve-service.ps1" -o "%DIR%\serve-service.ps1" || goto :err
curl.exe -fsSL "%SRC%/index.html"              -o "%DIR%\index.html"        || goto :err

start "" "http://127.0.0.1:7817/"
echo.
echo   Your conversations: http://127.0.0.1:7817/
echo   Close this window to stop. Nothing was installed.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%DIR%\serve-service.ps1"
exit /b 0

:err
echo.
echo   Download failed - are you online? Nothing was changed on your computer.
pause
exit /b 1
