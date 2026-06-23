# Anna OS — Deploy to Your Watch

## Open the project

**Important:** The folder name `Anna:OS` contains a colon. Xcode's build system breaks on that character. Use the symlink:

```
open ~/Desktop/Anna-OS/AnnaOS.xcodeproj
```

(If the symlink is missing: `ln -s ~/Desktop/Anna:OS/AnnaOS ~/Desktop/Anna-OS`)

## First run (5 minutes)

1. Open `AnnaOS.xcodeproj` in Xcode 26.5
2. Select the **AnnaPhone** scheme
3. Signing & Capabilities → set your **Team** on both AnnaPhone and AnnaWatch targets
4. Plug in iPhone 15 (watch paired)
5. Select your iPhone as destination → **Run** (⌘R)
6. On iPhone, open **Anna** → paste Claude API key → Save
7. Anna installs on watch automatically

## What runs where

| Layer | Hardware | Job |
|-------|----------|-----|
| **AnnaWatch** | Apple Watch Series 11 | HealthKit HR, mic, silent calibration UI, Hey Anna gate, TTS when allowed |
| **AnnaPhone** | iPhone 15 | Claude API, Keychain, music CDN stream, tool proxy to Mac Mini |
| **begump.com** | Cloud edge | Music CDN now; Mac ↔ watch relay eventually (`/anna/tool`, `/anna/sync`) |
| **WatchConnectivity** | Both | Brain ↔ wrist messages |

## Security (Sentinel + local-only)

- iPhone: **Security** section — toggle each egress class (Claude, Mac LAN, music, begump relay off by default)
- Memories/health encrypted at rest (AES-GCM, Secure Enclave key)
- Mac: `~/Desktop/Anna:OS/security/anna-audit.sh` — full Sentinel audit
- See `SECURITY.md`

## Permissions (grant on first launch)

- Watch: Health (heart rate), Microphone
- iPhone: network (Claude + jsDelivr CDN)

## Music

Streams from `cdn.jsdelivr.net/gh/LacobusGump/music2.0@main` — same source as begump.com/radio/. No bundled MP3s.

## Mac Mini + begump bridge

In iPhone Anna settings:
- **LAN host:** `http://192.168.1.100:8765` — prime, fold, compile direct to Mac Mini
- **Fallback via begump.com** — when LAN fails, same tools relay through `https://begump.com/anna` (your computer ↔ watch edge; music already uses begump CDN)

See `MEMORY_AND_PROVIDER.md` § begump bridge.

## Verify build locally

```bash
cd ~/Desktop/Anna-OS   # not Anna:OS
xcodebuild -project AnnaOS.xcodeproj -target AnnaWatch \
  -sdk watchsimulator -arch arm64 CODE_SIGNING_ALLOWED=NO build
```

Watch target must show **BUILD SUCCEEDED** before you deploy.