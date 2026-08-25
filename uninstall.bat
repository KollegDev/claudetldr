@echo off
REM claudetldr uninstall - removes the sync service installed by setup.bat.
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "claudetldr" /f >nul 2>nul
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "claudetldr-sync" /f >nul 2>nul
powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" | Where-Object { $_.CommandLine -like '*serve-service.ps1*' -or $_.CommandLine -like '*sync-service.ps1*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }" >nul 2>nul
rd /s /q "%LOCALAPPDATA%\claudetldr" 2>nul
echo claudetldr sync removed.
echo Nothing else was left behind - the service never copied your data anywhere.
echo (If you used an older version, you may still have Downloads\claude-sessions.)
pause
