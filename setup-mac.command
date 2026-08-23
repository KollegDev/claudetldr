#!/bin/bash
# claudetldr setup (macOS, beta) - installs an invisible sync that mirrors
# your Claude conversations to ~/Downloads/claude-sessions.
# Downloaded files lose the execute bit, so run it with:
#     bash ~/Downloads/setup-mac.command
# Undo:  launchctl unload ~/Library/LaunchAgents/com.claudetldr.sync.plist
#        rm ~/Library/LaunchAgents/com.claudetldr.sync.plist
#        rm -rf "$HOME/Library/Application Support/claudetldr"
set -e
INSTALL="$HOME/Library/Application Support/claudetldr"
mkdir -p "$INSTALL"

cat > "$INSTALL/sync.sh" <<'SYNC'
#!/bin/bash
SRC="$HOME/Library/Application Support/Claude/local-agent-mode-sessions"
DST="$HOME/Downloads/claude-sessions"
while true; do
  if [ -d "$SRC" ]; then
    find "$SRC" -name audit.jsonl -print0 2>/dev/null | while IFS= read -r -d '' f; do
      rel="${f#$SRC/}"; out="$DST/$rel"
      if [ ! -f "$out" ] || [ "$f" -nt "$out" ]; then
        mkdir -p "$(dirname "$out")" && cp -p "$f" "$out" 2>/dev/null
      fi
    done
  fi
  sleep 2
done
SYNC
chmod +x "$INSTALL/sync.sh"

PLIST="$HOME/Library/LaunchAgents/com.claudetldr.sync.plist"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.claudetldr.sync</string>
  <key>ProgramArguments</key><array><string>$INSTALL/sync.sh</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict></plist>
PLIST_EOF
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"
echo "claudetldr sync installed (invisible)."
echo "Now open the viewer, click 'connect Cowork' and pick Downloads/claude-sessions once."
