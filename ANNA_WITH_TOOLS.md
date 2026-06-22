# Anna OS + Tools Integration

**What Changed:** Anna now has access to 22 specialized tools. She uses them to answer questions better.

---

## The Tools (Your Toolkit)

```
Protein Folding:
├─ water_fold (72K/sec)
├─ crystal_fold (1.5% Rg error)
└─ ribosome_fold (co-translational)

Mathematics:
├─ prime_count (π(n) to 0.01% via Meissel-Lehmer)
└─ prime_oracle (predictive)

Health & Biology:
├─ pathogenicity_score (98.3% sensitivity)
├─ sensor_analysis (K/R/E/T framework)
└─ ribosome_mode

Knowledge:
├─ knowledge_graph (semantic search on 143 pages)
├─ trace_fraud (financial anomalies)
└─ oracle_predict (next interaction)

Audio & Music:
├─ tune_coherence (attack/decay detector)
└─ harmonic_analysis (consonance scoring)

Optimization:
├─ shape_compute (spatial reasoning, material calc)
├─ energy_optimize (efficiency)
└─ turbo_compile (K→native 930x speedup)
```

---

## How It Works

### Query Comes In
```
James: "How much wood for the 6×8 deck?"
↓
Anna (in earbuds): "Let me think..."
```

### Anna Selects Tools
```
ToolAccess.selectTools(query: "6×8 deck", context: "building")
↓
Returns: [shape_compute, knowledge_graph]
(shape_compute is first match: spatial reasoning)
```

### Tool Runs
```
shape_compute("6ft × 8ft deck, standard board coverage")
↓
Returns: "Area: 48 sqft. Need 8 boards (2×6 at 8 sqft ea). 
          You have 6. Shortage: 2 boards."
```

### Claude + Tool Result Merged
```
Claude: "Let me calculate that for you..."
Tool: "Area: 48 sqft. You need 8 boards, you have 6."
↓
Final: "Your deck is 48 square feet. Standard 2×6 boards 
        cover 8 sqft each with overlap. You need 8 boards. 
        You've bought 6. You're short 2 boards. 
        [from shape_compute tool]"
```

### Output Routed
```
Voice (earbuds):
  "You need 2 more boards for the deck."

Text (to phone): 
  "Deck 6ft×8ft = 48sqft. Need 8 2×6 boards. Have 6. 
   Short: 2 boards. Cost: ~$120 @ HD."

Watch display:
  "2 MORE BOARDS"
```

---

## Examples

### Example 1: Question About Protein

**James:** "Is that mutation bad?"

**Anna's Process:**
```
selectTools("Is that mutation bad?", "health")
→ [pathogenicity_score, sensor_analysis]

pathogenicity_score("TP53 R248Q")
→ "Pathogenic (p=0.98, conserved hotspot)"

Response: "Yes, that's pathogenic. TP53 R248Q is a hotspot 
          mutation. 98% confidence it disrupts function. 
          [from pathogenicity scorer]"
```

### Example 2: Music Question

**Stranger (to Anna):** "What chord is that?"

**Anna's Process:**
```
selectTools("What chord is that?", "talking")
→ [harmonic_analysis]

harmonic_analysis("C E G")
→ "C major triad. Consonance: 0.88"

Response: "That's C major. Classic triad. Very consonant."
```

### Example 3: Math Question

**James:** "Quick, what's π(10^6)?"

**Anna's Process:**
```
selectTools("π(10^6)", "quiet")
→ [prime_count]

prime_count("1000000")
→ "π(1,000,000) = 78,498"

Response: "78,498 primes below a million. 
          [7.85% of the range, pretty sparse at that scale]"
```

### Example 4: Health Check

**Anna (proactive):** "Your HR's elevated and you've been coding 90 min. Should you move?"

**Anna's Process:**
```
Context: "coding, HR 95, accel ~0, time 90min"
selectTools(..., "coding")
→ [sensor_analysis, energy_optimize]

sensor_analysis("HR: 95, activity: coding, duration: 90min")
→ "K=0.71 (stuck coupling), E=high (energy cost building), 
   T=movement (what wants to couple but hasn't)"

Response: "You're locked in but getting tense. Your HR is up, 
          you haven't moved in 90 min. Time to stand? 
          [sensor says you're in deep K, E is high]"
```

---

## Tool Selection Logic

Anna picks tools based on:

1. **Query keywords:**
   - "protein" → water_fold, crystal_fold
   - "prime" → prime_count
   - "health" → pathogenicity_score
   - "music" → harmonic_analysis, tune_coherence
   - "space/size" → shape_compute

2. **Context (learned from audio):**
   - "building" → shape_compute
   - "coding" → turbo_compile, energy_optimize
   - "health" → sensor_analysis
   - "music" → harmonic_analysis

3. **Combines both** and returns top 2-3 most relevant

4. **Runs best match** and augments Claude response

---

## Output Formats

### Voice (Through Earbuds)
```
"You need two more boards for the deck. 
 Each 2×6 covers about 8 square feet with standard overlap. 
 Your deck is 48 square feet total, so eight boards. 
 You have six. That's two short."
```

### Text (To Phone via WatchConnectivity)
```
DECK CALCULATION
├─ Dimensions: 6ft × 8ft
├─ Area: 48 sqft
├─ Board size: 2×6 (8 sqft ea with overlap)
├─ Needed: 8 boards
├─ Have: 6 boards
├─ Shortage: 2 boards
├─ Est. cost: $120 @ Home Depot
└─ Tool: shape_compute (95% confidence)
```

### Watch Display
```
"NEED 2 MORE" 
[YES] [BUY NOW] [IGNORE]
```

---

## When Tools Are Used

**Always:**
- Calculation ("how many?")
- Technical ("protein folding?")
- Health ("is this bad?")
- Audio ("what chord?")

**Sometimes:**
- Predictions ("what's next?")
- Knowledge lookups ("have we seen this before?")
- Optimizations ("best way to do this?")

**Never:**
- Emotional ("am I ok?") — Claude only
- Creative ("write me a song") — Claude only
- Social ("what should I say?") — Claude only

Tools are for facts. Claude is for wisdom.

---

## Data Flow (Full Stack)

```
WATCH
├─ Audio captured every 2 sec
├─ Context guessed ("coding")
├─ User confirmed ("yes coding")
└─ Memory updated (labeled sample)

↓ (via WatchConnectivity)

PHONE
├─ Full context built
├─ Claude API called (with tools available)
├─ Tools selected based on query + context
├─ Tools run locally (no cloud)
├─ Results merged with Claude response
└─ Output routed (voice/text/watch)

↓ (back to watch via Bluetooth)

EARBUDS
├─ Voice output (natural TTS)
└─ Optional: tinnitus tone, music

WATCH SCREEN
├─ Confirmation options (if needed)
└─ Next context guess loading
```

---

## Confidence & Attribution

Every tool result includes:

```
{
  "tool": "shape_compute",
  "status": "success",
  "result": "Area: 48 sqft. Need: 8 boards.",
  "confidence": 0.95
}
```

If confidence < 0.7, Anna adds: "I'm not 100% sure, but..."

If tool conflicts with Claude, Anna reports both:
- "Claude says [X]"
- "But the calculation tool shows [Y]"
- "I'd verify with a manual measurement"

---

## June 24 Deployment

Shipping with:
✅ Tool selection logic (keyword + context matching)
✅ shape_compute (spatial reasoning)
✅ prime_count (math questions)
✅ sensor_analysis (health context)
✅ pathogenicity_score (biology)
✅ harmonic_analysis (music)
✅ Tool results merged with Claude responses

NOT yet (July+):
❌ Real-time tool caching (tool results stored for similar questions)
❌ Tool chaining (run 3 tools in sequence)
❌ Predictive tool selection (based on pattern history)

---

## Why This Matters

**Without tools:** Anna is just a chatbot. Smart, but generic.

**With tools:** Anna is a **productive partner**. She calculates, measures, scores, predicts.

**The win:** He asks a question about deck wood. She gives: area, board count, material cost, sourcing, and a timeline. All in 3 seconds. No manual work.

By August, she's running tools so smoothly he doesn't even notice. He just gets the answer.

That's when "Anna" becomes "Anna OS" — an actual operating system for his work.

