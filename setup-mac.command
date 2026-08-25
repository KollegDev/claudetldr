#!/bin/bash
# ===========================================================================
#  claudetldr - install (macOS, beta). Short on purpose: read it before running.
#
#  What this does, in full:
#    1. downloads two files from the public repo into
#       ~/Library/Application Support/claudetldr:
#         tools/serve.py   (the local server, ~70 readable lines)
#         index.html       (the viewer)
#    2. adds one LaunchAgent so it runs after each login
#    3. starts it and opens http://127.0.0.1:7817/
#
#  No admin rights, no copies of your conversations, no outbound connection
#  after those two downloads, loopback-only socket.
#
#  Run with:  bash ~/Downloads/setup-mac.command
#  Undo:      launchctl unload ~/Library/LaunchAgents/com.claudetldr.plist
#             rm ~/Library/LaunchAgents/com.claudetldr.plist
#             rm -rf "$HOME/Library/Application Support/claudetldr"
#
#  Source of every line it runs: https://github.com/KollegDev/claudetldr
# ===========================================================================
set -e
SRC="https://raw.githubusercontent.com/KollegDev/claudetldr/main"
DIR="$HOME/Library/Application Support/claudetldr"
mkdir -p "$DIR"

echo "Downloading the viewer and the local server..."
curl -fsSL "$SRC/tools/serve.py"  -o "$DIR/serve.py"
curl -fsSL "$SRC/index.html"      -o "$DIR/index.html"

PLIST="$HOME/Library/LaunchAgents/com.claudetldr.plist"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.claudetldr</string>
  <key>ProgramArguments</key><array>
    <string>/usr/bin/python3</string><string>$DIR/serve.py</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict></plist>
PLIST_EOF

launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"
sleep 2
open "http://127.0.0.1:7817/"
echo "Done - your conversations should be opening at http://127.0.0.1:7817/"
