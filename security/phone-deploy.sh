#!/bin/bash
# Deploy Anna to iPhone over USB. Run while phone is plugged into Mac Mini.
set -euo pipefail

UDID="00008120-000C6D0C1EB9A01E"
PROJECT="$HOME/Desktop/Anna:OS/AnnaOS/AnnaOS.xcodeproj"
SCHEME="AnnaPhone"
LAN_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo 192.168.1.164)"

echo "═══ ANNA PHONE DEPLOY (USB) ═══"
echo "iPhone 15 · iOS $(ideviceinfo -k ProductVersion 2>/dev/null || echo '?')"
echo "Mac LAN for Anna tools: http://${LAN_IP}:8765"
echo ""

if ! idevice_id -l 2>/dev/null | grep -q "$UDID"; then
  echo "✗ iPhone not detected on USB. Check cable + tap Trust on phone."
  exit 1
fi
echo "✓ iPhone connected on USB"

DM="$(idevicedevmodectl list -u "$UDID" 2>/dev/null | awk 'NR==2{print $2}')"
if [[ "$DM" != "enabled" ]]; then
  echo ""
  echo "Developer Mode is OFF. On your iPhone (2 taps):"
  echo "  Settings → Privacy & Security → Developer Mode → ON → restart → Turn On"
  echo ""
  echo "Waiting for you… (Ctrl+C to cancel)"
  while [[ "$(idevicedevmodectl list -u "$UDID" 2>/dev/null | awk 'NR==2{print $2}')" != "enabled" ]]; do
    sleep 3
  done
  echo "✓ Developer Mode enabled"
fi

"$HOME/Desktop/Anna:OS/security/jim-mac-mini.sh" anna-test >/dev/null

echo "Building AnnaPhone → iPhone…"
cd "$HOME/Desktop/Anna:OS/AnnaOS"
xcodebuild \
  -project AnnaOS.xcodeproj \
  -scheme "$SCHEME" \
  -destination "id=$UDID" \
  -allowProvisioningUpdates \
  build install 2>&1 | tail -20

echo ""
echo "✓ Done. Open Anna on iPhone."
echo "  Mac host: http://${LAN_IP}:8765"
echo "  Add Claude API key in app → Security → test Hey Anna on watch"