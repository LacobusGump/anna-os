#!/bin/bash
# Jim Mac Mini — Anna test lane. One script, no macOS maze.
#   ./jim-mac-mini.sh status
#   ./jim-mac-mini.sh anna-test    # reset + start what Anna needs
#   ./jim-mac-mini.sh lite         # pause heavy background agents
#   ./jim-mac-mini.sh full         # bring all begump agents back

set -euo pipefail

AGENTS="$HOME/Library/LaunchAgents"
ANNA_DIR="$HOME/Desktop/Anna:OS"
TOOLS_PY="$HOME/gump-private/turbo-internet/anna_tools_server.py"
LAN_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo 127.0.0.1)"
MAC_HOST="http://${LAN_IP}:8765"

ts() { date '+%H:%M:%S'; }

probe() {
  local name="$1" url="$2"
  if curl -s -m 2 "$url" >/dev/null 2>&1; then
    echo "  ✓ $name  $url"
  else
    echo "  ✗ $name  $url"
  fi
}

status() {
  echo ""
  echo "═══ JIM MAC MINI — $(ts) ═══"
  echo "LAN IP: $LAN_IP"
  echo "iPhone Mac host → $MAC_HOST"
  echo ""
  echo "Services:"
  probe "Quantum (501 qubits)" "http://127.0.0.1:1370/"
  probe "Anna tools" "$MAC_HOST/health"
  probe "License server" "http://127.0.0.1:8890/"
  probe "Harmonia reasoner" "http://127.0.0.1:8889/"
  probe "Turbo proxy" "http://127.0.0.1:8888/"
  probe "begump policy" "https://begump.com/anna/security-policy.json"
  echo ""
  echo "CPU hogs (top 3):"
  ps aux 2>/dev/null | awk 'NR>1 && $3>5.0 {printf "  %.0f%%  %s\n", $3, $11}' | head -3 || true
  echo ""
  echo "Anna Xcode:"
  echo "  open \"$ANNA_DIR/AnnaOS/AnnaOS.xcodeproj\""
  echo ""
}

ensure_plist() {
  local label="$1" plist="$AGENTS/${label}.plist"
  if [[ -f "$plist" ]]; then
    launchctl bootstrap "gui/$(id -u)" "$plist" 2>/dev/null || launchctl kickstart -k "gui/$(id -u)/${label}" 2>/dev/null || true
  fi
}

unload_optional() {
  for label in com.begump.grok-crawler com.begump.harmonia-autonomous; do
    launchctl bootout "gui/$(id -u)" "$AGENTS/${label}.plist" 2>/dev/null || true
    echo "  paused $label"
  done
}

load_optional() {
  for label in com.begump.grok-crawler com.begump.harmonia-autonomous; do
    ensure_plist "$label"
  done
}

anna_tools_agent() {
  mkdir -p "$AGENTS"
  cat > "$AGENTS/com.anna.tools.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.anna.tools</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/python3</string>
        <string>$TOOLS_PY</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/anna-tools.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/anna-tools.err</string>
</dict>
</plist>
PLIST
  launchctl bootout "gui/$(id -u)" "$AGENTS/com.anna.tools.plist" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$AGENTS/com.anna.tools.plist"
}

mac_prefs() {
  # Jim-style: see where you are, dock out of the way, less animation noise
  defaults write com.apple.finder ShowPathbar -bool true
  defaults write com.apple.finder AppleShowAllExtensions -bool true
  defaults write com.apple.finder _FXSortFoldersFirst -bool true
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true
  defaults write com.apple.dock orientation -string left
  defaults write com.apple.dock tilesize -int 48
  defaults write com.apple.dock autohide -bool false
  defaults write com.apple.dock magnification -bool false
  defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
  defaults write com.apple.universalaccess reduceMotion -bool true 2>/dev/null || true
  killall Finder Dock 2>/dev/null || true
  echo "  ✓ Finder path bar, dock left, reduced motion"
}

clean_shell() {
  # Fix install.sh duplicate-comment spam in .zprofile
  cat > "$HOME/.zprofile" <<'ZP'
eval "$(/opt/homebrew/bin/brew shellenv zsh)"
export PATH="$HOME/.elan/bin:$PATH"
[ -f "$HOME/.quantum_boot.sh" ] && bash "$HOME/.quantum_boot.sh" 2>/dev/null
ZP
  echo "  ✓ .zprofile cleaned (was duplicated quantum hooks)"
}

anna_test() {
  echo ""
  echo "═══ ANNA TEST MODE ═══"
  clean_shell
  mac_prefs
  unload_optional

  echo "Starting Anna stack..."
  ensure_plist com.gump.quantum
  ensure_plist com.begump.license-server
  ensure_plist com.begump.harmonia-reasoner
  chmod +x "$ANNA_DIR/security/jim-mac-mini.sh" "$TOOLS_PY" 2>/dev/null || true
  anna_tools_agent
  sleep 2

  echo ""
  echo "Phone settings:"
  echo "  Mac LAN host: $MAC_HOST"
  echo "  Cloud Brain: ON · Mac LAN tools: ON · begump relay: OFF"
  echo ""
  status
}

case "${1:-status}" in
  status) status ;;
  anna-test|test) anna_test ;;
  lite) unload_optional; status ;;
  full) load_optional; ensure_plist com.gump.quantum; ensure_plist com.begump.turbo-internet; status ;;
  *) echo "Usage: $0 {status|anna-test|lite|full}"; exit 1 ;;
esac