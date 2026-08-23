# sync-service.ps1 - invisible background sync for the claudetldr viewer.
#
# Mirrors every audit.jsonl from the Claude desktop app's session store
# (blocked for browsers by Chrome's AppData blocklist) into
# Documents\claude-sessions, which the viewer CAN pick and remember.
# Copies only files that changed; timestamps are preserved, so the
# viewer's sorting and ACTIVE badge keep working.
#
# Installed by setup.bat as a hidden logon task. ~0 CPU while idle.

$src = Join-Path $env:APPDATA 'Claude\local-agent-mode-sessions'
# Downloads, not Documents: Chrome's picker refuses Documents children on
# OneDrive-redirected setups ('contains system files'), Downloads works.
$dst = Join-Path $env:USERPROFILE 'Downloads\claude-sessions'

# single instance guard
$created = $false
$mutex = New-Object System.Threading.Mutex($true, 'Global\claudetldr-sync', [ref]$created)
if (-not $created) { exit 0 }

$skip = @('outputs','uploads','node_modules','.git','.claude')

function Find-Audits([string]$dir, [int]$depth) {
    if ($depth -gt 8) { return }
    $audit = Join-Path $dir 'audit.jsonl'
    if (Test-Path -LiteralPath $audit -PathType Leaf) { $audit; return }   # session dir - stop descending
    try { $subs = [IO.Directory]::EnumerateDirectories($dir) } catch { return }
    foreach ($d in $subs) {
        if ($skip -contains [IO.Path]::GetFileName($d)) { continue }
        Find-Audits $d ($depth + 1)
    }
}

while ($true) {
    try {
        if (Test-Path -LiteralPath $src) {
            foreach ($a in Find-Audits $src 0) {
                try {
                    $rel = $a.Substring($src.Length + 1)
                    $out = Join-Path $dst $rel
                    $sf  = [IO.FileInfo]::new($a)
                    $of  = [IO.FileInfo]::new($out)
                    if (-not $of.Exists -or $of.Length -ne $sf.Length -or $of.LastWriteTimeUtc -lt $sf.LastWriteTimeUtc) {
                        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($out)) | Out-Null
                        Copy-Item -LiteralPath $a -Destination $out -Force
                    }
                } catch { } # file locked mid-write etc. - next pass gets it
            }
        }
    } catch { }
    Start-Sleep -Seconds 2
}
