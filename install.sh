#!/bin/bash
# claudetldr installer (macOS / Linux). Read it before running - that is the point.
#
#   curl -fsSL https://kollegdev.github.io/claudetldr/install.sh | bash
#
# What it does:
#   1. downloads two files into ~/Library/Application Support/claudetldr
#      (or ~/.local/share/claudetldr on Linux):
#        tools/serve.py  - the local server (~120 readable lines)
#        index.html      - the viewer
#   2. macOS: adds one LaunchAgent so it starts after each login
#   3. starts it and opens http://127.0.0.1:7817/
#
# No admin rights, no copies of your conversations, no outbound connection
# afterwards, no telemetry. The server listens on 127.0.0.1 only.
#
# Undo (macOS): launchctl unload ~/Library/LaunchAgents/com.claudetldr.plist
#               rm ~/Library/LaunchAgents/com.claudetldr.plist
#               rm -rf "$HOME/Library/Application Support/claudetldr"
# Source: https://github.com/KollegDev/claudetldr
set -e
SRC="https://raw.githubusercontent.com/KollegDev/claudetldr/main"

if [ "$(uname)" = "Darwin" ]; then
  DIR="$HOME/Library/Application Support/claudetldr"
else
  DIR="$HOME/.local/share/claudetldr"
fi
mkdir -p "$DIR"

echo "  downloading the viewer and the local server..."
curl -fsSL "$SRC/tools/serve.py" -o "$DIR/serve.py"
curl -fsSL "$SRC/index.html"     -o "$DIR/index.html"

pkill -f "claudetldr.*serve.py" 2>/dev/null || true

if [ "$(uname)" = "Darwin" ]; then
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
else
  nohup python3 "$DIR/serve.py" >/dev/null 2>&1 &
  sleep 2
  (xdg-open "http://127.0.0.1:7817/" >/dev/null 2>&1 &) || true
fi

echo ""
echo "  Done - your conversations are opening at http://127.0.0.1:7817/"
echo ""
