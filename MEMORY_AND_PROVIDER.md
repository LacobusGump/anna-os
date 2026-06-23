# Anna Memory + Provider Architecture

*Jim-only. Saved on Anna:OS / anna-os. Profile is seed; memories are life.*

---

## THE KEY — what Anna remembers

Anna tracks **anything Jim tells her to remember**, at the granularity of real life:

| Type | Example |
|------|---------|
| Inventory left | 5 eggs, 2 paint gallons, 40 screws, 12 2x6s |
| How Jim builds | Face screw deck, 3/16 gap, railing style |
| Materials lists | Work Johnson job vs home back deck |
| People + context | Shan on Route 22, last call with Mike about lumber |

**Not invented. Remembered.** Retrieval is always on. Storage is consent-gated.

---

## Air-gap consent (Person #1)

Jim is willing to give Anna **everything** eventually — calls, geo, full life stream. But the true companion model is:

> **Anna only stores what Jim says to remember.**

Triggers:
- `"Hey Anna, remember …"`
- `"don't forget …"`
- `"store this …"`
- iPhone quick-add (`build@work.deck_materials_list=…`)

Casual conversation uses memories but does **not** silently write new ones. Jim controls the air gap by naming what enters permanent storage.

Future: when Anna has her own phone number and listens on calls, Jim still says what to remember — or pre-authorizes scopes ("remember everything on work calls"). Person #1 sets the rules.

---

## Site scope — work deck ≠ home deck

Same word "deck" maps to different memories depending on **where** and **what just happened**.

### Geo-sync (easiest tell)
- `home` — house, back deck build style
- `farm` — Columbus NJ
- `work` — client jobs, Johnson deck materials list
- GPS radius match on iPhone → `currentSite`

### Call context (second tell)
Jim just hung up with a client about lumber → `"remember twelve 2x6s"` binds to **work**, not home.

v1: paste last call notes on iPhone.  
v2: CallKit on-device call metadata.  
v3: **Anna answers her own number** — provider edge.

### Quick-add format
```
inventory@home.eggs_count=5
build@home.deck_style=face screw, 3/16 gap, no picture frame
build@work.deck_materials_list=12x 2x6x12, deck screws, joist hangers
build@work.deck_how_jim_builds=double joist, blocking every 4ft
```

---

## Phone calls — hard, necessary, the edge

Anna needs call awareness to disambiguate:
- Which job site
- Which materials list
- Who Jim was talking to when he said "remember"

**Roadmap:**

| Phase | What |
|-------|------|
| v1 (now) | Paste last call on iPhone; parse topic/site hints |
| v2 | CallKit — detect call end, contact, duration; Jim confirms remember |
| v3 | **Anna as telecom provider** — Jim's number routes to Anna; she hears call, Jim says what to store |
| v4 | Full companion — geo + call + wrist + explicit remember; still Jim-gated writes |

**The edge:** Everyone has an AI app. Almost nobody has **a number that is their companion** — air-gapped by what they tell it to remember, but present on every call. Jim becomes a provider. That's the moat.

---

## Inventory — anything left

Not just kitchen. Any quantity Jim names:
- `inventory@home.paint_gallon_left=2`
- `inventory@work.lumber_2x6_count=12`
- `kitchen@home.eggs_count=5`

Anna recalls on wake: *"Last time you had 5 eggs left"* or *"Work site — 12 2x6s from last remember."*

---

## Code map

| File | Role |
|------|------|
| `LifeMemory.swift` | Store, site scope, remember consent, inventory |
| `SiteContext.swift` | Geo places, current site, manual override |
| `CallContext.swift` | Last call notes, site/topic hints |
| `PhoneBrain.swift` | Feeds site + call + memory into Claude |
| `JIM_PROFILE.md` | Human-readable spec |

iPhone = authoritative memory store. Watch = sync snapshot + Hey Anna utterance capture.

---

## begump.com bridge — computer ↔ watch

Jim's Mac Mini runs heavy tools (prime, fold, compile). Watch is narrow brain. iPhone is wide brain **today** — but eventually the wrist needs the computer when the phone isn't in pocket.

**begump.com is the relay edge** — same family as music CDN (`begump.com/radio/`, jsDelivr `music2.0`).

```
Mac Mini (home LAN)
    ↕ direct HTTP :8765 when reachable
iPhone (AnnaPhone)
    ↕ WatchConnectivity
Watch (AnnaWatch)

Eventually when LAN/phone gap:
Mac Mini → begump.com/anna → Watch (or iPhone cache)
```

| Path | Purpose |
|------|---------|
| `begump.com/anna/tool/{name}` | Proxy Mac tools when off-LAN |
| `begump.com/anna/sync/life-memory` | Memory snapshot to wrist |
| `begump.com/anna/sync/health` | Health substrate |
| `begump.com/anna/watch/message` | Hey Anna round-trip via cloud |

**v1 (now):** LAN to Mac Mini; begump for music only.  
**v2:** Toggle fallback — iPhone tries LAN, then `begump.com/anna`.  
**v3:** Watch pulls from begump when phone sleeping; Mac pushes state upstream.

Jim-only. Relay does not bypass remember consent — storage still gated.

Code: `BegumpBridge.swift`, `ToolAccess.swift` (LAN then begump fallback).

---

## Example session

1. Jim at **work**, just called **Johnson** about deck lumber.
2. iPhone: paste call note → site_hint=work.
3. Jim: *"Hey Anna, remember twelve 2x6s, joist hangers, and the face-screw pattern we talked about."*
4. Anna stores `build@work.deck_materials_list`, confirms one line.
5. Saturday at **home**: *"Hey Anna, I'm starting the back deck."*
6. Anna pulls `build@home.deck_style` — not the Johnson work list.

That's the companion.