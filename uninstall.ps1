# claudetldr - complete removal.
#
#   iwr -useb https://kollegdev.github.io/claudetldr/uninstall.ps1 | iex
#
# Stops the local server, removes the autostart entry and deletes the
# install folder. Your conversations are untouched - claudetldr never
# copied or modified them.

$dir = Join-Path $env:LOCALAPPDATA 'claudetldr'

Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -like '*serve-service.ps1*' } |
    ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force } catch { } }

foreach ($n in 'claudetldr', 'claudetldr-sync') {
    Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' `
                        -Name $n -ErrorAction SilentlyContinue
}
Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue

Write-Host ''
Write-Host '  claudetldr removed. Your conversations were never touched.' -ForegroundColor Green
Write-Host ''
