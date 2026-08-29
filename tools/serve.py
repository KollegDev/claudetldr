#!/usr/bin/env python3
"""serve.py - claudetldr local viewer service (macOS/Linux counterpart of
tools/serve-service.ps1).

Serves the viewer and your conversations on 127.0.0.1 ONLY. Being a local
process, it reads the Claude session store directly - nothing is copied,
picked or permitted.

  GET /ping            -> {"ok":true,"app":"claudetldr"}   (no user data)
  GET /                -> index.html from this folder
  GET /api/sessions    -> [{id,title,mtime,size}]
  GET /api/audit?id=.. -> one session's audit.jsonl

No admin rights, no outbound network, no telemetry, loopback-bound socket.
Stop it with Ctrl+C (or unload the LaunchAgent).
"""
import http.server, json, os, socketserver, sys, urllib.parse, zlib

PORT = int(os.environ.get('CLAUDETLDR_PORT', '7817'))
HERE = os.path.dirname(os.path.abspath(__file__))
SKIP = {'outputs', 'uploads', 'node_modules', '.git', '.claude'}

def store_dir():
    mac = os.path.expanduser('~/Library/Application Support/Claude/local-agent-mode-sessions')
    if os.path.isdir(mac):
        return mac
    return os.path.expanduser('~/.config/Claude/local-agent-mode-sessions')

STORE = store_dir()

_title_cache = {}          # meta path -> (mtime, title): titles change rarely

def _title_for(meta):
    try:
        st = os.stat(meta)
    except OSError:
        return None
    hit = _title_cache.get(meta)
    if hit and hit[0] == st.st_mtime:
        return hit[1]
    title = None
    try:
        with open(meta, encoding='utf-8') as f:
            title = (json.load(f) or {}).get('title')
    except Exception:
        title = None
    _title_cache[meta] = (st.st_mtime, title)
    return title

def sessions():
    out = []
    def walk(d, depth):
        if depth > 8:
            return
        try:
            entries = list(os.scandir(d))
        except OSError:
            return
        for e in entries:
            if not e.is_dir() or e.name in SKIP:
                continue
            audit = os.path.join(e.path, 'audit.jsonl')
            if os.path.isfile(audit):
                title = _title_for(os.path.join(d, e.name + '.json'))   # Cowork's own title
                try:
                    st = os.stat(audit)
                except OSError:
                    continue
                out.append({'id': os.path.relpath(audit, STORE), 'title': title,
                            'mtime': int(st.st_mtime * 1000), 'size': st.st_size})
            else:
                walk(e.path, depth + 1)
    if os.path.isdir(STORE):
        walk(STORE, 0)
    out.sort(key=lambda s: s['mtime'], reverse=True)
    return out

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _send(self, code, ctype, body, extra=None):
        self.send_response(code)
        self.send_header('Content-Type', ctype)
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parts = urllib.parse.urlparse(self.path)
        if parts.path == '/ping':
            # presence probe for the public site: no user data, hence the only
            # route readable by another origin
            self._send(200, 'application/json; charset=utf-8',
                       b'{"ok":true,"app":"claudetldr"}',
                       {'Access-Control-Allow-Origin': '*'})
        elif parts.path in ('/', '/index.html'):
            # installed layout: index.html next to this script.
            # repo checkout: one level up (tools/serve.py).
            path = os.path.join(HERE, 'index.html')
            if not os.path.isfile(path):
                path = os.path.join(os.path.dirname(HERE), 'index.html')
            if os.path.isfile(path):
                with open(path, 'rb') as f:
                    self._send(200, 'text/html; charset=utf-8', f.read())
            else:
                self._send(404, 'text/plain', b'index.html missing')
        elif parts.path == '/api/sessions':
            body = json.dumps(sessions()).encode('utf-8')
            # the list changes only when a session is touched: let an unchanged
            # poll answer with 304 and no body at all
            etag = '"%d-%d"' % (len(body), zlib.crc32(body))
            if self.headers.get('If-None-Match') == etag:
                self.send_response(304)
                self.send_header('ETag', etag)
                self.send_header('Cache-Control', 'no-store')
                self.end_headers()
            else:
                self._send(200, 'application/json; charset=utf-8', body, {'ETag': etag})
        elif parts.path == '/api/audit':
            q = urllib.parse.parse_qs(parts.query)
            sid = q.get('id', [''])[0]
            try:
                frm = max(0, int(q.get('from', ['0'])[0]))
            except ValueError:
                frm = 0
            full = os.path.realpath(os.path.join(STORE, sid))
            if (full.startswith(os.path.realpath(STORE) + os.sep)
                    and os.path.basename(full) == 'audit.jsonl'
                    and os.path.isfile(full)):
                st = os.stat(full)
                # audit.jsonl is append-only: serve just the new bytes.
                # If the file shrank (rotated/replaced), fall back to the whole
                # file and tell the client to reset via X-From.
                if frm > st.st_size:
                    frm = 0
                with open(full, 'rb') as f:
                    if frm:
                        f.seek(frm)
                    data = f.read()
                self._send(200, 'text/plain; charset=utf-8', data,
                           {'X-Mtime': str(int(st.st_mtime * 1000)),
                            'X-Size': str(st.st_size),
                            'X-From': str(frm)})
            else:
                self._send(404, 'text/plain', b'not found')
        else:
            self._send(404, 'text/plain', b'not found')

class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True

if __name__ == '__main__':
    try:
        srv = Server(('127.0.0.1', PORT), Handler)
    except OSError:
        sys.exit('Port %d is busy - claudetldr may already be running.' % PORT)
    print('claudetldr is running: http://127.0.0.1:%d/  (Ctrl+C to stop)' % PORT)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
