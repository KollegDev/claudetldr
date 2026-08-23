@echo off
REM claudetldr uninstall - removes the sync service installed by setup.bat.
schtasks /End /TN "claudetldr-sync" >nul 2>nul
schtasks /Delete /F /TN "claudetldr-sync" >nul 2>nul
powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" | Where-Object { $_.CommandLine -like '*sync-service.ps1*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }" >nul 2>nul
rd /s /q "%LOCALAPPDATA%\claudetldr" 2>nul
echo claudetldr sync removed.
echo The mirrored copies in Documents\claude-sessions were kept - delete that
echo folder manually if you no longer want them.
pause
