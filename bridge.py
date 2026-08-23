#!/usr/bin/env python3
"""bridge.py - turn a Cowork session's audit.jsonl into a live chat mirror.

Reads only. Writes only chat-mirror.md into an output folder you choose.
Nothing leaves your machine.

  python bridge.py                       # newest session, watch mode
  python bridge.py --once                # single snapshot, then exit
  python bridge.py --out C:\\path\\folder  # where chat-mirror.md goes
  python bridge.py --file <audit.jsonl>  # a specific session
  python bridge.py --list                # list recent sessions

Point the tldr viewer at the output folder and it updates itself.
"""
import argparse
import glob
import json
import os
import sys
import time
from datetime import datetime

DEFAULT_OUT = None  # resolved to the current working directory at runtime
SKIP_TYPES = {"system", "command_lifecycle", "rate_limit_event",
              "tool_progress", "result"}


# ---------------------------------------------------------------- discovery
def audit_root():
    appdata = os.environ.get("APPDATA")
    if appdata:
        p = os.path.join(appdata, "Claude", "local-agent-mode-sessions")
        if os.path.isdir(p):
            return p
    mac = os.path.expanduser("~/Library/Application Support/Claude/local-agent-mode-sessions")
    if os.path.isdir(mac):
        return mac
    lin = os.path.expanduser("~/.config/Claude/local-agent-mode-sessions")
    return lin if os.path.isdir(lin) else None


def find_audits():
    root = audit_root()
    if not root:
        return []
    files = glob.glob(os.path.join(root, "**", "audit.jsonl"), recursive=True)
    return sorted(files, key=os.path.getmtime, reverse=True)


# ------------------------------------------------------------------ parsing
def blocks_to_text(content):
    """Assistant content is a list of blocks; keep text, drop thinking/tool noise."""
    if isinstance(content, str):
        return content
    out = []
    if isinstance(content, list):
        for b in content:
            if not isinstance(b, dict):
                continue
            t = b.get("type")
            if t == "text" and b.get("text"):
                out.append(b["text"])
            elif t == "tool_use":
                out.append("[tool: %s]" % b.get("name", "?"))
    return "\n".join(out)


def is_real_user_turn(ev):
    """Real typed messages vs tool results that also arrive as type 'user'."""
    if ev.get("type") != "user":
        return False
    if ev.get("parent_tool_use_id"):
        return False
    msg = ev.get("message") or {}
    content = msg.get("content")
    if isinstance(content, str):
        return bool(content.strip())
    if isinstance(content, list):
        # tool_result blocks disqualify; plain text blocks are a real turn
        if any(isinstance(b, dict) and b.get("type") == "tool_result" for b in content):
            return False
        return bool(blocks_to_text(content).strip())
    return False


def parse_audit(path):
    """-> list of {role, text, ts}, assistant chunks coalesced by message id."""
    events = []
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                ev = json.loads(line)
            except Exception:
                continue
            if not isinstance(ev, dict) or ev.get("type") in SKIP_TYPES:
                continue
            events.append(ev)

    events.sort(key=lambda e: str(e.get("timestamp") or e.get("_audit_timestamp") or ""))

    turns = []
    open_msg = {}  # message id -> index in turns
    for ev in events:
        etype = ev.get("type")
        ts = ev.get("timestamp") or ev.get("_audit_timestamp") or ""
        if etype == "user":
            if not is_real_user_turn(ev):
                continue
            text = blocks_to_text((ev.get("message") or {}).get("content"))
            if text.strip():
                turns.append({"role": "You", "text": text.strip(), "ts": ts})
                open_msg.clear()  # a new user turn closes previous assistant streams
        elif etype == "assistant":
            msg = ev.get("message") or {}
            text = blocks_to_text(msg.get("content"))
            if not text.strip():
                continue
            mid = msg.get("id")
            if mid and mid in open_msg:
                prev = turns[open_msg[mid]]
                if text.strip() not in prev["text"]:
                    prev["text"] += "\n" + text.strip()
            else:
                turns.append({"role": "Claude", "text": text.strip(), "ts": ts})
                if mid:
                    open_msg[mid] = len(turns) - 1
    return turns


# ----------------------------------------------------------------- emitting
def to_mirror(turns, title):
    lines = ["# Chat Originals (auto-synced from audit.jsonl)",
             "", "<!-- %s -->" % title, ""]
    turn_no = 0
    for t in turns:
        if t["role"] == "You":
            turn_no += 1
        icon = "\U0001f9d1" if t["role"] == "You" else "\U0001f916"
        stamp = ""
        if t["ts"]:
            try:
                stamp = " - " + datetime.fromisoformat(
                    t["ts"].replace("Z", "+00:00")).strftime("%H:%M")
            except Exception:
                stamp = ""
        lines.append("### %s %s - turn %d%s" % (icon, t["role"], max(turn_no, 1), stamp))
        lines.append(t["text"])
        lines.append("")
    return "\n".join(lines) + "\n"


def write_mirror(path, text):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, path)



def guard_gitignore(out_dir):
    """Append mirror outputs to an existing .gitignore; never create one."""
    gi = os.path.join(out_dir, ".gitignore")
    if not os.path.isfile(gi):
        return
    try:
        with open(gi, encoding="utf-8", errors="replace") as f:
            content = f.read()
        missing = [p for p in ("chat-mirror.md", "chat-originals.md")
                   if p not in content]
        if missing:
            with open(gi, "a", encoding="utf-8") as f:
                f.write("\n# claudetldr runtime output (added by bridge.py)\n")
                for p in missing:
                    f.write(p + "\n")
            print("added %s to .gitignore" % ", ".join(missing))
    except Exception:
        pass


def session_title(path, max_lines=400):
    """First real user message = the session's natural title."""
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for i, line in enumerate(f):
                if i > max_lines:
                    break
                try:
                    ev = json.loads(line)
                except Exception:
                    continue
                if isinstance(ev, dict) and is_real_user_turn(ev):
                    text = blocks_to_text((ev.get("message") or {}).get("content"))
                    text = " ".join(text.split())
                    return (text[:70] + "...") if len(text) > 70 else text
    except Exception:
        pass
    return "(no user message found)"


def pick_session(files):
    """Interactive menu over recent sessions, newest first. Enter = newest."""
    now = time.time()
    top = files[:8]
    print("Which conversation? (Enter = newest)\n")
    for i, p in enumerate(top, 1):
        mt = os.path.getmtime(p)
        active = "  [ACTIVE]" if now - mt < 300 else ""
        print("  %d) %s  %5.1f MB%s" % (
            i, datetime.fromtimestamp(mt).strftime("%d.%m %H:%M"),
            os.path.getsize(p) / 1048576, active))
        print("     %s" % session_title(p))
    try:
        choice = input("\n> ").strip()
    except EOFError:
        choice = ""
    if choice.isdigit() and 1 <= int(choice) <= len(top):
        return top[int(choice) - 1]
    return top[0]


# --------------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--file", help="specific audit.jsonl")
    ap.add_argument("--out", default=DEFAULT_OUT,
                    help="output folder (default: the folder you run this in)")
    ap.add_argument("--once", action="store_true", help="one snapshot, then exit")
    ap.add_argument("--list", action="store_true", help="list recent sessions")
    ap.add_argument("--interval", type=float, default=2.0, help="poll seconds")
    ap.add_argument("--latest", action="store_true",
                    help="skip the menu, take the newest session")
    args = ap.parse_args()

    if args.list:
        for p in find_audits()[:10]:
            print("%s  %7.1f MB  %s" % (
                datetime.fromtimestamp(os.path.getmtime(p)).strftime("%Y-%m-%d %H:%M"),
                os.path.getsize(p) / 1048576, session_title(p)))
            print("%s%s" % (" " * 24, p))
        return

    path = args.file
    if not path:
        found = find_audits()
        if not found:
            sys.exit("no audit.jsonl found - is the Claude desktop app installed?")
        if args.latest or len(found) == 1 or not sys.stdin.isatty():
            path = found[0]
        else:
            path = pick_session(found)
    print("session  : %s" % session_title(path))

    out_dir = os.path.abspath(args.out or os.getcwd())
    os.makedirs(out_dir, exist_ok=True)
    guard_gitignore(out_dir)
    out_file = os.path.join(out_dir, "chat-mirror.md")
    print("watching : %s" % path)
    print("writing  : %s" % out_file)
    print("connect the tldr viewer to this folder: %s\n" % out_dir)

    last_size, last_written = -1, ""
    while True:
        try:
            size = os.path.getsize(path)
            if size != last_size:
                last_size = size
                turns = parse_audit(path)
                text = to_mirror(turns, os.path.basename(os.path.dirname(path)))
                if text != last_written:
                    write_mirror(out_file, text)
                    last_written = text
                    print("\r%s  %d turns (%d KB)        " % (
                        datetime.now().strftime("%H:%M:%S"),
                        len(turns), len(text) // 1024), end="", flush=True)
        except FileNotFoundError:
            print("\rsource file vanished - waiting…", end="", flush=True)
        except Exception as e:
            print("\rerror: %r" % e, end="", flush=True)
        if args.once:
            print()
            return
        time.sleep(args.interval)


if __name__ == "__main__":
    main()
