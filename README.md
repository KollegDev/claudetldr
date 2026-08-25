# claudetldr

**Long AI chats become unreadable walls of text. This makes them navigable.**

A collapsible map of any Claude conversation: your messages as waypoints, each
response collapsed to one line, the full original one click away — plus search
and keyboard jumps.

👉 **[Open the viewer](https://kollegdev.github.io/claudetldr/)** — no install, no build step.

Nothing leaves your browser. No server, no telemetry, no account. The viewer is
a single dependency-free HTML file you can also right-click-save and use offline.

---

## Two ways to use it

### 1. One double-click (Windows — v16)

Download **`setup.bat`** from the viewer and double-click it. That's the entire
setup: it installs a loopback-only service, opens your conversations in the
browser, and starts itself after every logon. No folder to pick, no permission
dialog, no copies of your data anywhere.

It works because the service is a local process, not a web page: it reads the
session store directly and serves both the viewer and the conversations at
`http://127.0.0.1:7817` (bookmark it). Sessions are listed by their real Cowork
titles, newest first, with an ACTIVE badge on running ones, and the open chat
follows the live session. `uninstall.bat` removes everything.

> Why a local service? Chrome's File System Access blocklist hard-refuses
> AppData/Library — in the folder picker, for dropped FSA handles, and even
> through junctions (all three verified). A hosted page can never read the
> store directly and persistently; serving the page from localhost sidesteps
> the whole problem, and the loopback socket needs no admin rights and is not
> reachable from the network.

### 1b. Zero install: drag & drop

No setup at all: drag the `local-agent-mode-sessions` folder onto the page
(Windows: `Win+R` → `%APPDATA%\Claude`; macOS: Finder →
`~/Library/Application Support/Claude`). The legacy drop API reads folders the
picker refuses, including live re-reads — but dropped folders can't be
remembered, so re-drop after each reload. Chrome/Edge required; pasting works
in any browser.

### 2. Paste any chat (works everywhere)

Open the viewer, select-all + copy your conversation, paste it into the page.
It splits the transcript into turns and renders the collapsible map. Works with
Claude, and with any chat you can copy as text.

---

## Files

| Path | What it is |
|---|---|
| `index.html` | The viewer. Single file, no dependencies. Reads `audit.jsonl` directly. |
| `setup.bat` / `uninstall.bat` | One-time install/removal of the local viewer service (Windows, generated). |
| `setup-mac.command` | Same for macOS (beta, generated). |
| `tools/serve-service.ps1.tpl` | Source of the local service: serves the viewer + reads the session store. |
| `tools/make-setup.py` | Generates both installers and embeds the viewer into them. |
| `tools/sync-service.ps1` | Pre-v16 mirror service, kept for reference. |
| `bridge.py` | Legacy CLI bridge: tails an `audit.jsonl` → `chat-mirror.md`. Not needed since v9. |
| `tools/cowork_inspector.py` | Read-only recon: what the Claude app exposes on your machine. |
| `tools/peek_audit.py` | Prints an `audit.jsonl`'s structure with values redacted. |

## Keyboard

| Key | Action |
|---|---|
| `t` | toggle the focused entry |
| `j` / `k` | next / previous turn |
| `Ctrl+V` | ingest a pasted conversation |

## Requirements

- Viewer: any modern browser (folder-watch mode: Chrome/Edge on localhost).
- `bridge.py`: Python 3.8+, standard library only.

## AI summaries (v12)

Responses without an inline TL;DR tag can be summarized **in the browser** by
Chrome's built-in Summarizer API (Gemini Nano) — free, offline, no key, no
server, mountable on any conversation. Generation is **on demand**: open a
chat and click "summarize this chat (N)"; a counter shows progress (roughly
5-20s per response on typical hardware). Results are cached locally by
content hash, so already-summarized responses appear instantly in every chat,
free of charge — only new material costs compute, and only when you ask.
If the model isn't on the machine yet, the button reads "enable AI summaries"
(Chrome downloads it once; needs Chrome/Edge 138+, ~22GB free disk, 16GB RAM
or a 4GB-VRAM GPU). Inline TL;DR tags, where present, always win; without
model and tags you get the first-line preview.

## Roadmap

- Send-to-Cowork bridge (compose locally, inject into the app)
- Export a session as a standalone HTML file

## License

MIT
