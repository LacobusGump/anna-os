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

## Example session

1. Jim at **work**, just called **Johnson** about deck lumber.
2. iPhone: paste call note → site_hint=work.
3. Jim: *"Hey Anna, remember twelve 2x6s, joist hangers, and the face-screw pattern we talked about."*
4. Anna stores `build@work.deck_materials_list`, confirms one line.
5. Saturday at **home**: *"Hey Anna, I'm starting the back deck."*
6. Anna pulls `build@home.deck_style` — not the Johnson work list.

That's the companion.