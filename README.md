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

### 1. Paste any chat (works everywhere)

Open the viewer, select-all + copy your conversation, paste it into the page.
It splits the transcript into turns and renders the collapsible map. Works with
Claude, and with any chat you can copy as text.

### 2. Live mode for Claude Cowork (Windows / macOS)

The Claude desktop app writes each session to a local `audit.jsonl`. `bridge.py`
reads it and keeps a mirror file updated, so the viewer follows your session in
real time — no copying, no pasting, no browser extension.

```bash
cd any-folder-you-like
python bridge.py            # watch the newest session (--list shows all)
```

Then open **[the viewer](https://kollegdev.github.io/claudetldr/)**, click
"connect workspace folder", and pick that same folder. The viewer remembers it:
after a reload, reconnecting is one click (or automatic). If the folder is a
git repo, bridge.py adds its output files to your .gitignore by itself.

> The folder picker needs Chrome or Edge on `http://localhost` (the File System
> Access API is blocked on `file://`). Pasting works in any browser.

---

## Files

| Path | What it is |
|---|---|
| `index.html` | The viewer. Single file, no dependencies. |
| `bridge.py` | Tails a Cowork session's `audit.jsonl` → `chat-mirror.md`. |
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
