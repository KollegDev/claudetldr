#!/usr/bin/env python3
"""peek_audit.py - show the STRUCTURE of a Cowork audit.jsonl, values redacted.

Usage:
  python peek_audit.py             (auto-finds the newest audit.jsonl)
  python peek_audit.py <path>      (specific file)

Prints: line count, frequency of top-level keys and 'type'/'role' values,
and skeletons of the first/last lines with every long string truncated -
so the output is safe to share: structure, not content.
"""
import glob
import json
import os
import sys

MAX_STR = 60


def newest_audit():
    base = os.path.join(os.environ.get("APPDATA", ""), "Claude",
                        "local-agent-mode-sessions")
    files = glob.glob(os.path.join(base, "**", "audit.jsonl"), recursive=True)
    if not files:
        sys.exit("no audit.jsonl found under %s" % base)
    return max(files, key=os.path.getmtime)


def skeleton(x, depth=0):
    if depth > 6:
        return "..."
    if isinstance(x, dict):
        return {k: skeleton(v, depth + 1) for k, v in list(x.items())[:12]}
    if isinstance(x, list):
        s = [skeleton(v, depth + 1) for v in x[:3]]
        if len(x) > 3:
            s.append("...+%d more" % (len(x) - 3))
        return s
    if isinstance(x, str):
        return x if len(x) <= MAX_STR else x[:30] + "...[len %d]" % len(x)
    return x


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else newest_audit()
    print("file:", path)
    keys, types, roles, n = {}, {}, {}, 0
    first, last = [], []
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            n += 1
            try:
                obj = json.loads(line)
            except Exception:
                continue
            if isinstance(obj, dict):
                for k in obj:
                    keys[k] = keys.get(k, 0) + 1
                t = obj.get("type") or obj.get("event") or obj.get("kind")
                if t:
                    types[str(t)] = types.get(str(t), 0) + 1
                r = obj.get("role") or (obj.get("message") or {}).get("role") \
                    if isinstance(obj.get("message"), dict) else obj.get("role")
                if r:
                    roles[str(r)] = roles.get(str(r), 0) + 1
            if len(first) < 3:
                first.append(obj)
            last.append(obj)
            if len(last) > 3:
                last.pop(0)
    print("lines:", n)
    print("top-level keys:", dict(sorted(keys.items(), key=lambda x: -x[1])[:15]))
    print("'type'-ish values:", dict(sorted(types.items(), key=lambda x: -x[1])[:15]))
    print("'role' values:", roles)
    for label, batch in (("FIRST", first), ("LAST", last)):
        for obj in batch:
            print("--- %s ---" % label)
            print(json.dumps(skeleton(obj), ensure_ascii=False, indent=1)[:1200])


if __name__ == "__main__":
    main()
