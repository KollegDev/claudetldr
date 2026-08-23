"""Tests for bridge.py: turn reconstruction from a synthetic audit.jsonl."""
import json
import os
import sys
import tempfile

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import bridge  # noqa: E402

FIXTURE = [
    {"type": "user", "parent_tool_use_id": None, "client_platform": "desktop_app",
     "timestamp": "2026-08-22T14:36:41Z",
     "message": {"role": "user", "content": "first question"}},
    {"type": "command_lifecycle", "state": "queued", "timestamp": "2026-08-22T14:36:45Z"},
    {"type": "system", "subtype": "init", "timestamp": "2026-08-22T14:36:46Z"},
    # one assistant message streamed as three events sharing an id
    {"type": "assistant", "timestamp": "2026-08-22T14:36:50Z", "session_id": "sub",
     "message": {"id": "m1", "role": "assistant",
                 "content": [{"type": "thinking", "thinking": "secret", "signature": "s"}]}},
    {"type": "assistant", "timestamp": "2026-08-22T14:36:51Z", "session_id": "sub",
     "message": {"id": "m1", "role": "assistant",
                 "content": [{"type": "text", "text": "part one."}]}},
    {"type": "assistant", "timestamp": "2026-08-22T14:36:52Z", "session_id": "sub",
     "message": {"id": "m1", "role": "assistant",
                 "content": [{"type": "text", "text": "part two."}]}},
    # tool result arriving as a 'user' event -> must be ignored
    {"type": "user", "parent_tool_use_id": "tu1", "timestamp": "2026-08-22T14:36:55Z",
     "message": {"role": "user",
                 "content": [{"type": "tool_result", "content": "listing"}]}},
    {"type": "user", "parent_tool_use_id": None, "client_platform": "desktop_app",
     "timestamp": "2026-08-22T14:40:00Z",
     "message": {"role": "user", "content": "second question"}},
    {"type": "assistant", "timestamp": "2026-08-22T14:40:05Z",
     "message": {"id": "m2", "role": "assistant",
                 "content": [{"type": "text", "text": "final answer"}]}},
    {"type": "result", "is_error": False, "num_turns": 2},
]


def main():
    with tempfile.TemporaryDirectory() as d:
        path = os.path.join(d, "audit.jsonl")
        with open(path, "w", encoding="utf-8") as f:
            for ev in FIXTURE:
                f.write(json.dumps(ev) + "\n")
        turns = bridge.parse_audit(path)

    checks = [
        ("four turns total", len(turns) == 4),
        ("two user turns", sum(t["role"] == "You" for t in turns) == 2),
        ("tool_result filtered", all("listing" not in t["text"] for t in turns)),
        ("thinking dropped", all("secret" not in t["text"] for t in turns)),
        ("chunks coalesced",
         any("part one." in t["text"] and "part two." in t["text"] for t in turns)),
        ("order preserved", turns[0]["text"] == "first question"),
        ("mirror renders", "\U0001f9d1 You" in bridge.to_mirror(turns, "t")),
    ]
    failed = 0
    for name, cond in checks:
        print(("  ok  " if cond else "  FAIL ") + name)
        failed += 0 if cond else 1
    print("\n%d passed, %d failed" % (len(checks) - failed, failed))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
