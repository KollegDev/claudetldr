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

### 1. Connect the Claude session store (no CLI — v9)

The Claude desktop app writes each session to a local `audit.jsonl`. The viewer
reads those files directly: **drag the `local-agent-mode-sessions` folder onto
the page** —

| OS | Where to find it |
|---|---|
| Windows | `Win+R` → `%APPDATA%\Claude` |
| macOS | Finder → `~/Library/Application Support/Claude` |

The page scans the folder itself, lists every conversation by title (newest
first, with an ACTIVE badge on running sessions), and follows the one you open
live — re-parsing on every change. No bridge process, no copying, no extension.

> Why drag & drop instead of the picker button? Chrome's File System Access
> blocklist refuses AppData/Library in the folder picker *and* for dropped
> FSA handles — but the legacy `webkitGetAsEntry` drop API reads those folders
> fine, including live re-reads. The "connect Cowork" button still works for
> folders outside AppData and is remembered across reloads; dropped folders
> must be re-dropped after a reload (legacy entries can't be persisted).
> Chrome/Edge required; pasting works in any browser.

### 2. Paste any chat (works everywhere)

Open the viewer, select-all + copy your conversation, paste it into the page.
It splits the transcript into turns and renders the collapsible map. Works with
Claude, and with any chat you can copy as text.

---

## Files

| Path | What it is |
|---|---|
| `index.html` | The viewer. Single file, no dependencies. Reads `audit.jsonl` directly. |
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

## Roadmap

- Optional cheap-model summaries for chats without TL;DR tags
- Send-to-Cowork bridge (compose locally, inject into the app)
- Export a session as a standalone HTML file

## License

MIT
