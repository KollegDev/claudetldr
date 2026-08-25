# claudetldr - portable start. Installs nothing, remembers nothing.
#
#   iwr -useb https://kollegdev.github.io/claudetldr/run.ps1 | iex
#
# Downloads the viewer and the local server into a temp folder, opens
# http://127.0.0.1:7817/ and serves your conversations until you close this
# window (Ctrl+C). No registry entry, no autostart, no admin rights, no
# outbound connection afterwards. Delete %TEMP%\claudetldr to erase it.
#
# Source: https://github.com/KollegDev/claudetldr

$ErrorActionPreference = 'Stop'
$src = 'https://raw.githubusercontent.com/KollegDev/claudetldr/main'
$dir = Join-Path $env:TEMP 'claudetldr'

New-Item -ItemType Directory -Force -Path $dir | Out-Null
Invoke-WebRequest -UseBasicParsing "$src/tools/serve-service.ps1" -OutFile (Join-Path $dir 'serve-service.ps1')
Invoke-WebRequest -UseBasicParsing "$src/index.html"              -OutFile (Join-Path $dir 'index.html')

Start-Process 'http://127.0.0.1:7817/'
Write-Host ''
Write-Host '  claudetldr is running: http://127.0.0.1:7817/' -ForegroundColor Green
Write-Host '  Nothing was installed. Press Ctrl+C to stop.'
Write-Host ''
& (Join-Path $dir 'serve-service.ps1')
