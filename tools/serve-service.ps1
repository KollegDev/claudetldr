# serve-service.ps1 - claudetldr local viewer service.
#
# Serves the viewer and your conversations on 127.0.0.1 ONLY. Because this is a
# local process (not a web page), it can read the Claude session store directly,
# so nothing has to be copied, picked or permitted.
#
#   GET /ping            -> {"ok":true,"app":"claudetldr"}   (no user data)
#   GET /                -> index.html from this folder
#   GET /api/sessions    -> [{id,title,mtime,size}]
#   GET /api/audit?id=.. -> one session's audit.jsonl
#
# What it does NOT do: no admin rights, no outbound network, no telemetry,
# no writing anywhere except its own folder. The socket is loopback-bound,
# so nothing outside this computer can reach it.
#
# Stop it:      close the window (portable mode) or run uninstall.bat
# Read it here: https://github.com/KollegDev/claudetldr/blob/main/tools/serve-service.ps1

param([int]$Port = 7817)

$store = Join-Path $env:APPDATA 'Claude\local-agent-mode-sessions'
$here  = Split-Path -Parent $MyInvocation.MyCommand.Path
$skip  = @('outputs','uploads','node_modules','.git','.claude')

# single instance guard
$created = $false
$mutex = New-Object System.Threading.Mutex($true, 'Global\claudetldr-serve', [ref]$created)
if (-not $created) { Write-Host 'claudetldr is already running.'; exit 0 }

# Titles change rarely, and ConvertFrom-Json is the slowest thing here, so a
# session's title is only re-read when its metadata file's timestamp moves.
$titleCache = @{}
function Get-Title([string]$meta) {
    if (-not (Test-Path -LiteralPath $meta -PathType Leaf)) { return $null }
    try { $mt = [IO.File]::GetLastWriteTimeUtc($meta).Ticks } catch { return $null }
    $hit = $titleCache[$meta]
    if ($hit -and $hit.Ticks -eq $mt) { return $hit.Title }
    $title = $null
    try {
        $m = Get-Content -LiteralPath $meta -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($m.title) { $title = [string]$m.title }
    } catch { }
    $titleCache[$meta] = @{ Ticks = $mt; Title = $title }
    return $title
}

function Get-Sessions {
    $out = New-Object System.Collections.Generic.List[object]
    function Walk([string]$dir, [int]$depth) {
        if ($depth -gt 8) { return }
        try { $subs = [IO.Directory]::EnumerateDirectories($dir) } catch { return }
        foreach ($d in $subs) {
            $name = [IO.Path]::GetFileName($d)
            if ($skip -contains $name) { continue }
            $audit = Join-Path $d 'audit.jsonl'
            if (Test-Path -LiteralPath $audit -PathType Leaf) {
                try {
                    $fi = [IO.FileInfo]::new($audit)
                    $title = Get-Title (Join-Path $dir ($name + '.json'))   # Cowork's own title
                    $out.Add([pscustomobject]@{
                        id    = $audit.Substring($store.Length + 1)
                        title = $title
                        mtime = [int64]([DateTimeOffset]$fi.LastWriteTimeUtc).ToUnixTimeMilliseconds()
                        size  = $fi.Length
                    })
                } catch { }
            } else {
                Walk $d ($depth + 1)
            }
        }
    }
    if (Test-Path -LiteralPath $store) { Walk $store 0 }
    return ($out | Sort-Object -Property mtime -Descending)
}

function Send-Response($stream, [int]$code, [string]$ctype, [byte[]]$body, [hashtable]$extra) {
    $status = @{ 200 = 'OK'; 304 = 'Not Modified'; 404 = 'Not Found' }[$code]
    if (-not $status) { $status = 'OK' }
    $sb = "HTTP/1.1 $code $status`r`nContent-Type: $ctype`r`nContent-Length: $($body.Length)`r`n" +
          "Cache-Control: no-store`r`nX-Content-Type-Options: nosniff`r`n"
    if ($extra) { foreach ($k in $extra.Keys) { $sb += "$k`: $($extra[$k])`r`n" } }
    $sb += "Connection: close`r`n`r`n"
    $head = [Text.Encoding]::ASCII.GetBytes($sb)
    $stream.Write($head, 0, $head.Length)
    if ($body.Length) { $stream.Write($body, 0, $body.Length) }
    $stream.Flush()
}

$listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, $Port)
try { $listener.Start() } catch { Write-Host "Port $Port is busy - claudetldr may already be running."; exit 1 }
Write-Host "claudetldr is running: http://127.0.0.1:$Port/   (close this window to stop)"

while ($true) {
    $client = $null
    try {
        $client = $listener.AcceptTcpClient()
        $client.ReceiveTimeout = 5000
        $stream = $client.GetStream()
        $buf = New-Object byte[] 8192
        $n = $stream.Read($buf, 0, $buf.Length)
        if ($n -le 0) { $client.Close(); continue }
        $path = ((([Text.Encoding]::ASCII.GetString($buf, 0, $n) -split "`r`n")[0]) -split ' ')[1]
        if (-not $path) { $path = '/' }

        if ($path -eq '/ping' -or $path.StartsWith('/ping?')) {
            # presence probe for the public site: carries no user data, so this
            # is the only route that any other origin may read
            Send-Response $stream 200 'application/json; charset=utf-8' `
                ([Text.Encoding]::ASCII.GetBytes('{"ok":true,"app":"claudetldr"}')) `
                @{ 'Access-Control-Allow-Origin' = '*' }
        }
        elseif ($path -eq '/' -or $path.StartsWith('/?') -or $path -eq '/index.html') {
            # installed layout: index.html sits next to this script.
            # repo checkout: it sits one level up (tools/serve-service.ps1).
            $file = Join-Path $here 'index.html'
            if (-not (Test-Path -LiteralPath $file)) {
                $file = Join-Path (Split-Path -Parent $here) 'index.html'
            }
            if (Test-Path -LiteralPath $file) {
                Send-Response $stream 200 'text/html; charset=utf-8' ([IO.File]::ReadAllBytes($file)) $null
            } else {
                Send-Response $stream 404 'text/plain' ([Text.Encoding]::ASCII.GetBytes('index.html missing')) $null
            }
        }
        elseif ($path -eq '/api/sessions') {
            $json = (Get-Sessions | ConvertTo-Json -Depth 4 -Compress)
            if (-not $json) { $json = '[]' }
            if ($json[0] -ne '[') { $json = '[' + $json + ']' }
            $body = [Text.Encoding]::UTF8.GetBytes($json)
            # unchanged list -> 304, no body (the client polls this every 15s)
            $tag = '"' + $body.Length + '-' + ([BitConverter]::ToString(
                     [Security.Cryptography.MD5]::Create().ComputeHash($body)) -replace '-','').Substring(0,12) + '"'
            $inm = ''
            foreach ($h in ($req -split "`r`n")) {
                if ($h -match '^(?i)If-None-Match:\s*(.+)$') { $inm = $Matches[1].Trim() }
            }
            if ($inm -eq $tag) {
                Send-Response $stream 304 'application/json; charset=utf-8' ([byte[]]@()) @{ 'ETag' = $tag }
            } else {
                Send-Response $stream 200 'application/json; charset=utf-8' $body @{ 'ETag' = $tag }
            }
        }
        elseif ($path.StartsWith('/api/audit')) {
            $id = $null; $from = 0
            if ($path.Contains('?')) {
                foreach ($kv in ($path.Substring($path.IndexOf('?') + 1) -split '&')) {
                    $p = $kv -split '=', 2
                    if ($p.Length -ne 2) { continue }
                    if ($p[0] -eq 'id')   { $id = [Uri]::UnescapeDataString($p[1]) }
                    if ($p[0] -eq 'from') { [int64]::TryParse($p[1], [ref]$from) | Out-Null }
                }
            }
            if ($from -lt 0) { $from = 0 }
            $ok = $false; $full = $null
            if ($id) {
                try { $full = [IO.Path]::GetFullPath((Join-Path $store $id)) } catch { $full = $null }
                if ($full -and $full.StartsWith($store, [StringComparison]::OrdinalIgnoreCase) -and
                    [IO.Path]::GetFileName($full) -eq 'audit.jsonl' -and
                    (Test-Path -LiteralPath $full -PathType Leaf)) { $ok = $true }
            }
            if ($ok) {
                $fi = [IO.FileInfo]::new($full)
                $mt = [int64]([DateTimeOffset]$fi.LastWriteTimeUtc).ToUnixTimeMilliseconds()
                $size = $fi.Length
                # audit.jsonl is append-only: serve only the bytes after $from.
                # If the file shrank (rotated), restart from 0 and say so.
                if ($from -gt $size) { $from = 0 }
                $bytes = [byte[]]@()
                try {
                    $fs = [IO.File]::Open($full, 'Open', 'Read', 'ReadWrite')   # tolerate live writes
                    try {
                        if ($from -gt 0) { $fs.Seek($from, 'Begin') | Out-Null }
                        $ms = New-Object IO.MemoryStream
                        $fs.CopyTo($ms)
                        $bytes = $ms.ToArray()
                    } finally { $fs.Close() }
                } catch { }
                Send-Response $stream 200 'text/plain; charset=utf-8' $bytes `
                    @{ 'X-Mtime' = $mt; 'X-Size' = $size; 'X-From' = $from }
            } else {
                Send-Response $stream 404 'text/plain' ([Text.Encoding]::ASCII.GetBytes('not found')) $null
            }
        }
        else {
            Send-Response $stream 404 'text/plain' ([Text.Encoding]::ASCII.GetBytes('not found')) $null
        }
    } catch { }
    finally { if ($client) { try { $client.Close() } catch { } } }
}
