# claudetldr installer.  Read this before running it - that is the point.
#
#   iwr -useb https://kollegdev.github.io/claudetldr/install.ps1 | iex
#
# What it does:
#   1. downloads two files into %LOCALAPPDATA%\claudetldr
#        serve-service.ps1  - the local server (~140 readable lines)
#        index.html         - the viewer
#   2. adds ONE per-user autostart entry (HKCU ...\Run\claudetldr)
#   3. starts it hidden and opens http://127.0.0.1:7817/
#
# What it does not do: no admin rights, no copies of your conversations,
# no outbound connection afterwards, no telemetry, no account. The server
# listens on 127.0.0.1 only, so nothing outside this PC can reach it.
#
# Undo:  iwr -useb https://kollegdev.github.io/claudetldr/uninstall.ps1 | iex
# Source: https://github.com/KollegDev/claudetldr

$ErrorActionPreference = 'Stop'
$src  = 'https://raw.githubusercontent.com/KollegDev/claudetldr/main'
$dir  = Join-Path $env:LOCALAPPDATA 'claudetldr'
$port = 7817

Write-Host ''
Write-Host '  claudetldr' -ForegroundColor Cyan
Write-Host '  installing into' $dir

New-Item -ItemType Directory -Force -Path $dir | Out-Null
Invoke-WebRequest -UseBasicParsing "$src/tools/serve-service.ps1" -OutFile (Join-Path $dir 'serve-service.ps1')
Invoke-WebRequest -UseBasicParsing "$src/index.html"              -OutFile (Join-Path $dir 'index.html')

# stop an older instance so this version takes over
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -like '*serve-service.ps1*' } |
    ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force } catch { } }

# start with no console window, now and after every logon
$vbs = Join-Path $dir 'run-hidden.vbs'
$ps1 = Join-Path $dir 'serve-service.ps1'
Set-Content -Path $vbs -Encoding ASCII -Value @"
CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File ""$ps1""", 0, False
"@
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' `
                 -Name 'claudetldr' -Value ("wscript.exe `"$vbs`"")
Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' `
                    -Name 'claudetldr-sync' -ErrorAction SilentlyContinue

Start-Process wscript.exe -ArgumentList "`"$vbs`""
Start-Sleep -Milliseconds 1500
Start-Process "http://127.0.0.1:$port/"

Write-Host ''
Write-Host '  Done - your conversations are opening in the browser.' -ForegroundColor Green
Write-Host "  Bookmark http://127.0.0.1:$port/   (starts by itself after every logon)"
Write-Host '  Remove:  iwr -useb https://kollegdev.github.io/claudetldr/uninstall.ps1 | iex'
Write-Host ''
