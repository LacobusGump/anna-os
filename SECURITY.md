# Anna Security — Sentinel + Local-Only

*Integrated from Jim's `gump-private/sentinel`. No cloud. No mousetrap. $0.*

---

## Two layers

| Layer | Where | What |
|-------|-------|------|
| **Sentinel** | Mac Mini | tripwire, portcheck, connwatch, firewall audit — pure bash |
| **AnnaSecurity** | iPhone + Watch | encrypted storage, egress whitelist, explicit toggles |

---

## Mousetrap avoidance

What Anna will **never** do by default:

- Upload memories or health to any server
- Enable begump cloud relay without explicit toggle
- Bind services to `0.0.0.0` (Sentinel flags `*:port`)
- Run telemetry, analytics, or crash reporters
- Auto-enable cloud features after an update

What requires **Jim's explicit opt-in**:

| Toggle | Egress |
|--------|--------|
| Cloud Brain | `api.anthropic.com` only, your API key |
| Mac LAN tools | `127.0.0.1` / `192.168.x` / `10.x` only |
| Music CDN | `cdn.jsdelivr.net` only |
| begump relay | `begump.com/anna` — off by default |
| Security policy | `begump.com/anna/security-policy.json` + `license.begump.com/validate` — always allowed |

Every allowed request is logged **locally** on device (`anna_egress.log`). Never transmitted.

**Policy channel is separate from begump relay.** Security manifest fetches even when relay is OFF — that's how Jim pushes model/egress updates without touching memories.

---

## Encrypted at rest

All Jim data files use **AES-GCM** via CryptoKit:

- `anna_life_memory.enc`
- `jim_health_profile.enc`
- `anna_call_context.enc`
- `anna_sites.enc`

Key lives in Keychain: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` (Secure Enclave backed on device).

Legacy plaintext `.json` files auto-migrate on first load.

---

## Mac Mini — run Sentinel

```bash
cd ~/Desktop/Anna:OS/security
chmod +x anna-audit.sh
./anna-audit.sh          # full audit
./anna-audit.sh watch    # continuous
./anna-audit.sh ports    # catch *:8080 style leaks
```

Logs: `~/.anna-sentinel/sentinel.log`

Anna-specific ports whitelisted in `sentinel/config/sentinel.conf`:
- 1370 quantum, 8765 Anna tools, 8888 turbo, 8889 reasoner, 8890 license

**Rule:** dev servers always `--bind 127.0.0.1`. Never `python -m http.server 8080` without bind.

---

## iPhone — Security settings

Anna app → **Security — Sentinel local-only**

- Toggle each egress class independently
- View local egress log count
- Save → persists to UserDefaults + syncs begump relay flag

Anna app → **Coupling License**

- Enter `GUMP-XXXX-XXXX-XXXX` key (Stripe subscription via `license_server.py`)
- **Activate & Recouple** → POST `license.begump.com/validate` → K=1.868 + `security_policy` JSON
- **Refresh Policy** → fetch `begump.com/anna/security-policy.json` (no key required)
- Offline grace: 14 days on bundled `security-policy.default.json`
- Memories never in policy payload — only model, egress hosts, default toggles

---

## Code map

| File | Role |
|------|------|
| `AnnaSecurity.swift` | Policy, toggles, mousetrap rules |
| `CouplingLicense.swift` | Port of `gump.coupling_license` — K decay, recouple |
| `SecurityPolicySync.swift` | Fetch/apply policy from begump + license validate |
| `SecurityPolicyTypes.swift` | Policy JSON schema |
| `NetworkGuard.swift` | Egress whitelist + local log |
| `SecureStorage.swift` | AES-GCM encrypt all Jim data |
| `KeychainHelper.swift` | API key, license key, device-only accessibility |
| `security/anna-security-policy.json` | Canonical policy → deploy to begump.com |
| `security/sentinel/` | Full Sentinel copy from gump-private |
| `security/anna-audit.sh` | One-command Mac audit |

---

## begump bridge under security

begump relay is **transport**, not storage. Even when enabled:

- Memories still encrypted on device
- Remember consent still gates writes
- Relay only for Mac tool fallback when LAN fails

Local-only path preferred: Watch → iPhone → Mac LAN.

---

*Born from port 8080 open for 20 days. Never again.*