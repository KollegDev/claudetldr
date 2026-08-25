# serve-service.ps1 - claudetldr local viewer service (generated; see tools/make-setup.py)
#
# Serves the viewer AND your conversations from 127.0.0.1 only. Because this is
# a local process (not a web page), it reads the Claude session store directly -
# no mirror folder, no folder picker, no permission dialog. Zero steps for the
# user after one double-click on setup.bat.
#
#   GET /                -> the viewer (embedded below as base64)
#   GET /api/sessions    -> [{id,title,mtime,size,active}]
#   GET /api/audit?id=.. -> raw audit.jsonl of one session
#
# Loopback TcpListener: no admin rights, no firewall prompt, not reachable
# from the network. ~0 CPU while idle.

$port = {PORT}
$store = Join-Path $env:APPDATA 'Claude\local-agent-mode-sessions'
$skip = @('outputs','uploads','node_modules','.git','.claude')
$HTML_B64 = '{HTML_B64}'

# single instance guard
$created = $false
$mutex = New-Object System.Threading.Mutex($true, 'Global\claudetldr-serve', [ref]$created)
if (-not $created) { exit 0 }

$html = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($HTML_B64))

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
                    $title = $null
                    $meta = Join-Path $dir ($name + '.json')
                    if (Test-Path -LiteralPath $meta -PathType Leaf) {
                        try {
                            $m = Get-Content -LiteralPath $meta -Raw -Encoding UTF8 | ConvertFrom-Json
                            if ($m.title) { $title = [string]$m.title }
                        } catch { }
                    }
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
    $status = @{ 200 = 'OK'; 400 = 'Bad Request'; 404 = 'Not Found' }[$code]
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

$listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, $port)
try { $listener.Start() } catch { exit 1 }   # port taken = another instance

while ($true) {
    $client = $null
    try {
        $client = $listener.AcceptTcpClient()
        $client.ReceiveTimeout = 5000
        $stream = $client.GetStream()
        $buf = New-Object byte[] 8192
        $n = $stream.Read($buf, 0, $buf.Length)
        if ($n -le 0) { $client.Close(); continue }
        $req = [Text.Encoding]::ASCII.GetString($buf, 0, $n)
        $line = ($req -split "`r`n")[0]
        $parts = $line -split ' '
        $path = if ($parts.Length -ge 2) { $parts[1] } else { '/' }

        if ($path -eq '/ping' -or $path.StartsWith('/ping?')) {
            # Presence probe for the public site. Carries NO user data, so it is
            # the only route with a permissive CORS header; /api/* stays
            # same-origin, i.e. unreadable by any other website.
            Send-Response $stream 200 'application/json; charset=utf-8' `
                ([Text.Encoding]::ASCII.GetBytes('{"ok":true,"app":"claudetldr"}')) `
                @{ 'Access-Control-Allow-Origin' = '*' }
        }
        elseif ($path -eq '/' -or $path.StartsWith('/?') -or $path -eq '/index.html') {
            Send-Response $stream 200 'text/html; charset=utf-8' ([Text.Encoding]::UTF8.GetBytes($html)) $null
        }
        elseif ($path -eq '/api/sessions') {
            $json = (Get-Sessions | ConvertTo-Json -Depth 4 -Compress)
            if (-not $json) { $json = '[]' }
            if ($json[0] -ne '[') { $json = '[' + $json + ']' }   # single object case
            Send-Response $stream 200 'application/json; charset=utf-8' ([Text.Encoding]::UTF8.GetBytes($json)) $null
        }
        elseif ($path.StartsWith('/api/audit')) {
            $q = ''
            if ($path.Contains('?')) { $q = $path.Substring($path.IndexOf('?') + 1) }
            $id = $null
            foreach ($kv in ($q -split '&')) {
                $p = $kv -split '=', 2
                if ($p[0] -eq 'id' -and $p.Length -eq 2) { $id = [Uri]::UnescapeDataString($p[1]) }
            }
            $ok = $false; $full = $null
            if ($id) {
                $candidate = Join-Path $store $id
                try { $full = [IO.Path]::GetFullPath($candidate) } catch { $full = $null }
                # path traversal guard: must stay inside the store and be an audit file
                if ($full -and $full.StartsWith($store, [StringComparison]::OrdinalIgnoreCase) -and
                    [IO.Path]::GetFileName($full) -eq 'audit.jsonl' -and
                    (Test-Path -LiteralPath $full -PathType Leaf)) { $ok = $true }
            }
            if ($ok) {
                $fi = [IO.FileInfo]::new($full)
                $mt = [int64]([DateTimeOffset]$fi.LastWriteTimeUtc).ToUnixTimeMilliseconds()
                $bytes = $null
                try {
                    $fs = [IO.File]::Open($full, 'Open', 'Read', 'ReadWrite')   # tolerate the app writing
                    try {
                        $ms = New-Object IO.MemoryStream
                        $fs.CopyTo($ms)
                        $bytes = $ms.ToArray()
                    } finally { $fs.Close() }
                } catch { $bytes = [byte[]]@() }
                Send-Response $stream 200 'text/plain; charset=utf-8' $bytes @{ 'X-Mtime' = $mt }
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
