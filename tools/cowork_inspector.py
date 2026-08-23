#!/usr/bin/env python3
"""cowork_inspector.py — read-only recon for the Claude desktop app.

Answers two questions on YOUR machine (nothing is modified, nothing sent):
  A) Does the Claude window expose its transcript via the OS accessibility
     tree (silent extraction possible)?
  C) Does the app store conversations in readable local files?

Usage (run while the Claude app is open with a conversation visible):
  python cowork_inspector.py --phrase "some exact words from your chat"

The --phrase should be 3-6 words you can see in the current conversation.
Finding it in the tree or in files is the decisive positive signal.
Writes cowork_inspector_report.txt next to the script.
"""
import argparse
import os
import platform
import sqlite3
import sys
import time

REPORT = []
MAX_TREE_NODES = 4000
MAX_TREE_DEPTH = 40
MAX_FILE_MB = 200
SNIPPET = 90


def log(line=""):
    print(line)
    REPORT.append(line)


# ---------------------------------------------------------------- A: UIA tree
def inspect_tree_windows(phrase):
    try:
        from pywinauto import Desktop
    except ImportError:
        log("[tree] pywinauto missing -> run: pip install pywinauto")
        return
    wins = [w for w in Desktop(backend="uia").windows()
            if "claude" in (w.window_text() or "").lower()]
    if not wins:
        log("[tree] no window with 'Claude' in the title found. Is the app open?")
        return
    for w in wins:
        log("[tree] window: %r  (class=%s)" % (w.window_text(), w.element_info.class_name))
        t0 = time.time()
        texts, node_count = [], 0
        stack = [(w.element_info, 0)]
        while stack and node_count < MAX_TREE_NODES:
            el, depth = stack.pop()
            node_count += 1
            if depth > MAX_TREE_DEPTH:
                continue
            name = (el.name or "").strip()
            if name and len(name) > 25:
                texts.append((depth, el.control_type, name))
            try:
                stack.extend((c, depth + 1) for c in el.children())
            except Exception:
                pass
        log("[tree] walked %d nodes in %.1fs; %d text nodes >25 chars"
            % (node_count, time.time() - t0, len(texts)))
        if node_count >= MAX_TREE_NODES:
            log("[tree] NOTE: node cap hit - tree is larger than what was walked")
        for depth, ctype, name in texts[:25]:
            log("    d%02d %-12s %s" % (depth, str(ctype)[:12], name[:SNIPPET].replace("\n", " ")))
        if phrase:
            hits = [t for t in texts if phrase.lower() in t[2].lower()]
            log("[tree] PHRASE %s: %d hit(s) in accessibility tree"
                % ("FOUND" if hits else "NOT FOUND", len(hits)))
            if hits:
                log("    -> mechanism A (silent tree reading) looks VIABLE")
        log("[tree] total text volume: %d chars across text nodes"
            % sum(len(t[2]) for t in texts))


def inspect_tree_macos(phrase):
    log("[tree] macOS: grant Terminal 'Accessibility' permission "
        "(System Settings > Privacy & Security), then this AX probe runs.")
    try:
        import subprocess
        script = (
            'tell application "System Events" to tell (first process whose '
            'name contains "Claude") to get value of attribute "AXRole" of '
            'every UI element of front window'
        )
        out = subprocess.run(["osascript", "-e", script],
                             capture_output=True, text=True, timeout=20)
        log("[tree] AX probe rc=%d out=%s err=%s"
            % (out.returncode, out.stdout[:300], out.stderr[:300]))
        log("[tree] (deep AX walking needs pyobjc/atomac; this only confirms "
            "the app is reachable via AX at all)")
    except Exception as e:
        log("[tree] AX probe failed: %r" % e)


# ------------------------------------------------------------- C: local data
def candidate_dirs():
    home = os.path.expanduser("~")
    sysname = platform.system()
    cands = []
    if sysname == "Windows":
        appdata = os.environ.get("APPDATA", os.path.join(home, "AppData", "Roaming"))
        local = os.environ.get("LOCALAPPDATA", os.path.join(home, "AppData", "Local"))
        for base in (appdata, local):
            if os.path.isdir(base):
                cands += [os.path.join(base, d) for d in os.listdir(base)
                          if "claude" in d.lower() or "anthropic" in d.lower()]
    elif sysname == "Darwin":
        base = os.path.join(home, "Library", "Application Support")
        if os.path.isdir(base):
            cands += [os.path.join(base, d) for d in os.listdir(base)
                      if "claude" in d.lower() or "anthropic" in d.lower()]
    else:
        base = os.path.join(home, ".config")
        if os.path.isdir(base):
            cands += [os.path.join(base, d) for d in os.listdir(base)
                      if "claude" in d.lower() or "anthropic" in d.lower()]
    return [c for c in cands if os.path.isdir(c)]


def grep_file(path, needles):
    """Search raw bytes for utf-8 and utf-16le encodings of each needle."""
    try:
        size = os.path.getsize(path)
        if size > MAX_FILE_MB * 1024 * 1024:
            return None
        hits = set()
        pats = []
        for n in needles:
            pats.append((n, n.encode("utf-8", "ignore")))
            pats.append((n, n.encode("utf-16-le", "ignore")))
        with open(path, "rb") as f:
            prev = b""
            while True:
                chunk = f.read(4 * 1024 * 1024)
                if not chunk:
                    break
                buf = prev + chunk
                for label, pat in pats:
                    if pat and pat in buf:
                        hits.add(label)
                prev = chunk[-200:]
        return hits
    except Exception:
        return None


def inspect_data(phrase):
    dirs = candidate_dirs()
    if not dirs:
        log("[data] no Claude/Anthropic app-data directory found")
        return
    needles = ["conversation", "assistant", '"role"']
    if phrase:
        needles.insert(0, phrase)
    for d in dirs:
        log("[data] scanning %s" % d)
        interesting = []
        for root, _, files in os.walk(d):
            for fn in files:
                p = os.path.join(root, fn)
                try:
                    sz = os.path.getsize(p)
                except OSError:
                    continue
                ext = os.path.splitext(fn)[1].lower()
                tag = ("sqlite" if ext in (".db", ".sqlite", ".sqlite3")
                       else "leveldb" if ext in (".ldb", ".log") and "leveldb" in root.lower()
                       else "json" if ext == ".json" else "")
                if tag or sz > 100 * 1024:
                    interesting.append((p, sz, tag))
        interesting.sort(key=lambda x: -x[1])
        log("[data] %d notable files; top 20:" % len(interesting))
        for p, sz, tag in interesting[:20]:
            rel = os.path.relpath(p, d)
            hits = grep_file(p, needles) or set()
            mark = " <== PHRASE FOUND" if phrase and phrase in hits else (
                   " (chat-like markers)" if hits else "")
            log("    %8.1f KB  %-7s %s%s" % (sz / 1024, tag, rel, mark))
            if tag == "sqlite" and hits:
                try:
                    con = sqlite3.connect("file:%s?mode=ro" % p.replace("\\", "/"), uri=True)
                    tables = [r[0] for r in con.execute(
                        "SELECT name FROM sqlite_master WHERE type='table'")]
                    log("             sqlite tables: %s" % ", ".join(tables[:15]))
                    con.close()
                except Exception as e:
                    log("             sqlite read failed: %r" % e)
        if phrase:
            found = any(phrase in (grep_file(p, [phrase]) or set())
                        for p, _, _ in interesting[:20])
            log("[data] PHRASE %s in local files"
                % ("FOUND -> mechanism C (file read) looks VIABLE" if found else "NOT FOUND"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--phrase", default="",
                    help="3-6 exact words visible in your current Claude conversation")
    args = ap.parse_args()
    log("cowork_inspector - %s - python %s" % (platform.platform(), sys.version.split()[0]))
    log("phrase: %r" % args.phrase)
    log("")
    log("=== A) accessibility tree ===")
    if platform.system() == "Windows":
        inspect_tree_windows(args.phrase)
    elif platform.system() == "Darwin":
        inspect_tree_macos(args.phrase)
    else:
        log("[tree] Linux desktop: AT-SPI probing not implemented in this inspector")
    log("")
    log("=== C) local app data ===")
    inspect_data(args.phrase)
    log("")
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "cowork_inspector_report.txt")
    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(REPORT) + "\n")
    print("\nreport written -> %s" % out)


if __name__ == "__main__":
    main()
