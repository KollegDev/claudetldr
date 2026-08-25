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

### 1. Fully automatic (Windows — v10)

Double-click **`setup.bat`** once. It registers an invisible background task
(PowerShell, no Python, no admin rights) that mirrors every conversation's
`audit.jsonl` into `Downloads\claude-sessions` within ~2 seconds of a change.
Then open the viewer, click **"connect Cowork"** and pick that folder — once.
The viewer remembers it and reconnects automatically on every visit.

The page scans the folder itself, lists every conversation by title (newest
first, with an ACTIVE badge on running sessions), and follows the one you open
live — re-parsing on every change. `uninstall.bat` removes everything.

> Why the mirror folder? Chrome's File System Access blocklist hard-refuses
> AppData/Library — in the folder picker, for dropped FSA handles, and even
> through junctions (all three verified). A browser page can never read the
> store directly and persistently; a one-time invisible sync is the minimum
> that makes "automatic" possible.

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
| `setup.bat` / `uninstall.bat` | One-time install/removal of the invisible sync service (Windows). |
| `tools/sync-service.ps1` | The sync service: mirrors `audit.jsonl` files to `Downloads\claude-sessions`. |
| `tools/run-hidden.vbs` | Starts the sync service without a console window. |
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
