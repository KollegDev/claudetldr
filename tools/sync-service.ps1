# sync-service.ps1 - invisible background sync for the claudetldr viewer.
#
# Mirrors the Claude desktop app's session store (blocked for browsers by
# Chrome's AppData blocklist) into Downloads\claude-sessions, which the
# viewer CAN pick and remember:
#   - every audit.jsonl (any size)
#   - every other file up to 512 KB (session metadata, titles, ...)
# Copies only files that changed; timestamps are preserved, so the
# viewer's sorting and ACTIVE badge keep working.
# Also writes store-manifest.txt (a listing of everything in the store)
# once per service start - used for diagnostics.
#
# Installed by setup.bat as a hidden autostart entry. ~0 CPU while idle.

$src = Join-Path $env:APPDATA 'Claude\local-agent-mode-sessions'
# Downloads, not Documents: Chrome's picker refuses Documents children on
# OneDrive-redirected setups ('contains system files'), Downloads works.
$dst = Join-Path $env:USERPROFILE 'Downloads\claude-sessions'

# single instance guard
$created = $false
$mutex = New-Object System.Threading.Mutex($true, 'Global\claudetldr-sync', [ref]$created)
if (-not $created) { exit 0 }

$skip = @('outputs','uploads','node_modules','.git','.claude')
$maxSmall = 524288   # 512 KB cap for non-audit files

function Write-Manifest {
    try {
        $lines = New-Object System.Collections.Generic.List[string]
        function WalkM([string]$dir, [int]$depth) {
            if ($depth -gt 8) { return }
            try { $files = [IO.Directory]::EnumerateFiles($dir) } catch { return }
            foreach ($f in $files) {
                try { $fi = [IO.FileInfo]::new($f); $lines.Add("$($fi.Length)`t$f") } catch { }
            }
            try { $subs = [IO.Directory]::EnumerateDirectories($dir) } catch { return }
            foreach ($d in $subs) {
                if ($skip -contains [IO.Path]::GetFileName($d)) { $lines.Add("DIR-SKIPPED`t$d"); continue }
                WalkM $d ($depth + 1)
            }
        }
        if (Test-Path -LiteralPath $src) { WalkM $src 0 }
        $claude = Join-Path $env:APPDATA 'Claude'
        try {
            foreach ($f in [IO.Directory]::EnumerateFiles($claude)) {
                $fi = [IO.FileInfo]::new($f); $lines.Add("$($fi.Length)`t$f")
            }
            foreach ($d in [IO.Directory]::EnumerateDirectories($claude)) { $lines.Add("DIR`t$d") }
        } catch { }
        [IO.Directory]::CreateDirectory($dst) | Out-Null
        [IO.File]::WriteAllLines((Join-Path $dst 'store-manifest.txt'), $lines)
    } catch { }
}

function Sync-Pass {
    function WalkS([string]$dir, [int]$depth) {
        if ($depth -gt 8) { return }
        try { $files = [IO.Directory]::EnumerateFiles($dir) } catch { return }
        foreach ($f in $files) {
            try {
                $sf = [IO.FileInfo]::new($f)
                if ($sf.Name -ne 'audit.jsonl' -and $sf.Length -gt $maxSmall) { continue }
                $rel = $f.Substring($src.Length + 1)
                $out = Join-Path $dst $rel
                $of  = [IO.FileInfo]::new($out)
                if (-not $of.Exists -or $of.Length -ne $sf.Length -or $of.LastWriteTimeUtc -lt $sf.LastWriteTimeUtc) {
                    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($out)) | Out-Null
                    Copy-Item -LiteralPath $f -Destination $out -Force
                }
            } catch { } # file locked mid-write etc. - next pass gets it
        }
        try { $subs = [IO.Directory]::EnumerateDirectories($dir) } catch { return }
        foreach ($d in $subs) {
            if ($skip -contains [IO.Path]::GetFileName($d)) { continue }
            WalkS $d ($depth + 1)
        }
    }
    if (Test-Path -LiteralPath $src) { WalkS $src 0 }
}

Write-Manifest
while ($true) {
    try { Sync-Pass } catch { }
    Start-Sleep -Seconds 2
}
