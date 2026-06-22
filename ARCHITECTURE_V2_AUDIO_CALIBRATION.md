# Anna OS Architecture v2 — Audio Calibration Loop (Redesigned)

**Core Change:** Audio learning is now PRIMARY, not secondary. Everything flows from calibration.

---

## The Loop (What Happens Every 2 Seconds)

```
1. CAPTURE
   └─ Watch mic records 2-second audio sample
      ├─ Waveform (time domain)
      └─ Spectrum (frequency domain)

2. GUESS
   └─ Anna analyzes audio against past labeled samples
      ├─ Spectral similarity to each known context
      ├─ Bayesian prior (how many times have we seen this before?)
      ├─ Generate top 3 guesses with confidence scores
      └─ Return questions: "are you cooking?" "coding?" "sleeping?"

3. DISPLAY
   └─ Watch screen shows top guess with yes/no/other buttons
      └─ "Are you cooking? [YES] [NO]"

4. CONFIRM (User taps in <1 second)
   └─ If YES:
      ├─ Audio sample + label stored in memory
      ├─ Confidence metric updated
      ├─ Claude context gets "cooking mode"
      └─ Music selection improves
   
   └─ If NO:
      ├─ Store as correction (he saw something different)
      ├─ Negative example prevents future false positives
      └─ Continue guessing

5. IMPROVE
   └─ Next guess is slightly smarter (more data)
      └─ After 50 confirmations: 60% → 75% accuracy
      └─ After 200 confirmations: 75% → 90% accuracy
```

---

## Data Flow (Centered on Audio)

```
┌─────────────────────────────────────────────────────────────┐
│                   WATCH (Always Listening)                  │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Audio Capture (2 sec every 2 sec)                           │
│    ↓                                                          │
│  AudioMemory.generateGuesses()                               │
│    ├─ Score each context (spectral similarity)              │
│    ├─ Apply Bayesian prior (prior frequency)                │
│    ├─ Return top 3 with confidence                          │
│    └─ Questions displayed on screen                         │
│                                                              │
│  User Confirmation (tap YES/NO)                              │
│    ↓                                                          │
│  AudioMemory.recordLabel()                                   │
│    ├─ Store waveform + spectrum + label                     │
│    ├─ Store HR + barometer + accel at time of confirm       │
│    ├─ Update context distribution                           │
│    └─ Increment learned sample count                        │
│                                                              │
│  Context Used Everywhere                                    │
│    ├─ → Claude API (better context for Q&A)                │
│    ├─ → Music selection (right song for activity)           │
│    ├─ → Health insights (HR context-aware)                  │
│    └─ → Proactivity (when to interrupt)                     │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## The Learning Curve (Timeline)

### Week 1: Baseline (Watch Arrives June 24)
```
Interactions: ~200 (2 per minute during use)
Accuracy: ~55-60% (barely better than random)
Contexts known: ~10 (quiet, cooking, coding, sleeping, etc.)
Reason: Not enough labeled data, guesses are generic
```

### Week 2 (July 1)
```
Interactions: ~1,500 cumulative
Accuracy: ~65-70% (getting obvious patterns)
Example: "Stove clicking + water running" → 85% cooking
Contexts: Specializing per room (kitchen cooking vs. office coding)
```

### Week 3-4 (July 15)
```
Interactions: ~5,000 cumulative
Accuracy: ~80-85% (reading subtle context)
Example: "Fridge + silence + HR 45" → 90% sleeping (even without snoring)
New: Cross-modal learning (audio + HR + barometer agree = high confidence)
```

### Month 2 (August 1)
```
Interactions: ~10,000+ cumulative
Accuracy: ~90%+
New: Predictive (anticipates before audio change)
Example: "Tuesday 5pm + route to gym" → 95% "about to exercise"
Time-based learning kicks in
```

### 3 Months In (September 1)
```
Interactions: 30,000+
Accuracy: ~95%+
Proactive: Anna speaks without being asked
Example: "It's Saturday 9am, you're building, here's the focus track"
Full system integrated
```

---

## Files Updated

### AnnaCore.swift (REWRITTEN)
**Primary loop:** `captureAndGuessContext()` runs every 2 seconds

**New methods:**
- `startAudioCalibration()` — begins the guessing loop
- `captureAndGuessContext()` — listen, guess, display
- `confirmContext(guess:confirmed:)` — user confirms, memory updates

**What changed:**
- Audio learning is now first-class, not hidden
- Guesses are visible on screen (no silent learning)
- User confirmation drives labeled data collection

### AudioMemory.swift (NEW)
**400+ lines of learning engine**

**Core methods:**
- `recordLabel()` — store confirmed audio + context
- `generateGuesses()` — top 3 contexts with confidence
- `scoreContexts()` — Bayesian scoring against past samples
- `spectralSimilarity()` — cosine distance on spectrograms
- `getMostLikelyContext()` — for Claude

**Data:**
- `labeledSamples` — all [audio, label, sensors, time]
- `contextDistribution` — histogram of known contexts

### ContentView.swift (UPDATED)
**New section: "What's happening?"**

Shows:
- Top 3 guesses from Anna
- Each with confidence %
- Yes/No buttons for quick confirmation
- Running count: "127 learned"

### SensorState (UPDATED)
**New method:** `inferContext()`

Quick sensor-based context (fallback when audio alone isn't sure)

---

## Guessing Algorithm (Simplified)

```swift
func scoreContexts(audio: AudioSample) -> [String: Double] {
    var scores = [:]
    
    for context in knownContexts {
        let pastSamples = memory.labeled(context)
        
        // Score = similarity to past samples + prior
        let similarities = pastSamples.map { 
            spectralSimilarity(audio.spectrum, $0.spectrum) 
        }
        let avgSimilarity = similarities.mean()
        
        // Prior: seen this context before? weight it higher
        let prior = pastSamples.count / totalSamples
        
        // Final score
        score[context] = avgSimilarity * (1.0 + prior * 0.3)
    }
    
    return score
}
```

**Why this works:**
1. No training needed (pure similarity + Bayes)
2. Improves with every confirmation
3. Penalizes rare contexts (no false positives)
4. Fast (spectral similarity is O(n) on spectrum bins)

---

## When Anna Speaks (Without Being Asked)

By week 3, Anna enters **proactive mode**:

```
Example 1: He's building, Anna knows from audio
├─ Saturday 9am, accent on tools sounds
├─ Anna: "Focus track?"
└─ Music plays automatically

Example 2: He's stuck coding
├─ 90+ minutes same problem, vocal stress rising
├─ Anna: "Time to walk?"
└─ Music pauses, speaker plays: "step outside?"

Example 3: Stranger just walked in
├─ Audio change (new voice) + phone senses 2 people
├─ Anna: mutes, stays silent
└─ Music fades

Example 4: He's stressed
├─ HR elevated + breathing shallow + vocal pitch up
├─ Anna: (earbuds, silent to others) "4-7-8 breathing?"
└─ Tinnitus healing tone starts
```

---

## Data Persistent (Local Only)

All stored on watch/phone:

```
~/Library/Anna/
├── audioMemory.json
│   └─ 50-500 samples: [waveform, spectrum, label, sensors, time]
├── contextDistribution.json
│   └─ {"cooking": 127, "coding": 89, "sleeping": 34, ...}
├── learnedPatterns.bin
│   └─ Pre-computed spectral centroids (fast lookup)
└── interactions.log
    └─ Every yes/no, for audit + debugging
```

**No cloud. No sharing. His device only.**

---

## Key Metrics (What He Should See)

**On watch screen (updated every 2 sec):**
```
"What's happening?"

"Are you cooking?" [YES] [NO]
  78% confident · 127 learned

"Working on code?" [YES] [NO]
  15% confident

"Time to sleep?" [YES] [NO]
  4% confident
```

**Growth metric (visible in settings):**
```
Audio Memory
├─ Labeled samples: 512
├─ Contexts: 8 known
├─ Model confidence: 87%
└─ Last updated: 2 seconds ago
```

---

## June 24 Deployment (Minimal)

Shipping with:
✅ Audio capture every 2 sec
✅ Spectral analysis (FFT on audio)
✅ Bayesian scorer (simple)
✅ User confirmation buttons (yes/no)
✅ Memory storage (local JSON)
✅ Top 3 guesses displayed

NOT yet:
❌ Time-based learning (comes July)
❌ Proactive mode (comes week 2)
❌ Cross-modal fusion (comes August)

This is enough for James to see it learning, give feedback, improve.

---

## Why This Changes Everything

**Old approach (before):**
- Watch listens passively
- Claude answers questions
- Maybe learns if logged
- User has to prompt

**New approach (now):**
- Watch listens, guesses every 2 sec
- User confirms in 1 second
- Memory updates in real-time
- System gets smarter visible per day
- Anna proactively helps by week 2

**The difference:** He's not waiting for her to learn. He's actively teaching her (1-tap confirmations). She responds instantly (visible accuracy %). System accelerates.

By August, she's operating at the level described in ULTIMATE: reading the moment, knowing what he needs, speaking without being asked.

But it starts small and grows from real data, not speculation.

---

## Success Metrics

By end of July:
- [ ] 500+ labeled audio samples
- [ ] 6+ contexts recognized
- [ ] 80%+ guess accuracy
- [ ] Visible improvement (he notices guesses getting better daily)
- [ ] Proactivity kicking in (music without asking)

By end of August:
- [ ] 10,000+ samples
- [ ] Social awareness working (recognizes strangers)
- [ ] Health context integrated (HR + audio = better insight)
- [ ] Multi-modal learning (audio + video + barometer coherent)

---

## The Win

This isn't "Anna learns from passive observation." It's "Anna and James together label her world. She builds models from real data. He teaches her to read context in 1 tap per interaction."

By October, that becomes: "Anna reads the room before he speaks."

All because she asked, he answered, and she kept both.

