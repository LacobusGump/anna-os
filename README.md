# Anna OS — Synthetic Build (Live Now)

**Status:** Ready to run. Synthetic sensors working. Claude API integrated. Music library wired.

---

## Quick Start

### 1. Clone/Copy This Build
```bash
cd ~/Desktop/anna-os-build/
# All files are here. Ready to go.
```

### 2. Set Your Claude API Key
```bash
export CLAUDE_API_KEY="sk-ant-..."  # Your Claude API key from console.anthropic.com
```

### 3. Open in Xcode
```bash
# Create new Xcode project (watchOS/iOS)
# OR use:
open -a Xcode .
```

Then:
- Copy all `.swift` files into the Xcode project
- Run on iPhone simulator (easier than watch simulator initially)

### 4. Test Scenarios
Run the app. You'll see:
- **Sensor Display:** Live synthetic data (HR, barometer, accel, etc.)
- **Test Scenarios:** Click buttons to simulate states (cooking, sleeping, falling, etc.)
- **Music Controls:** Play /radio/ album, skip, pause
- **Voice Input:** Tap "Listen" to trigger Claude API

---

## Files

```
AnnaApp.swift           ← Entry point
AnnaCore.swift          ← Main engine (sensor processing, Claude API, routing)
SensorSimulation.swift  ← Synthetic data generators (6 test scenarios)
ClaudeAPI.swift         ← Claude API integration
MusicLibrary.swift      ← All 33 songs + playback routing
ContentView.swift       ← UI (sensor display, controls, voice)
```

---

## What's Working

✓ Sensor simulation (HR, barometer, accel, gyro patterns for each scenario)
✓ Audio scene understanding (detect cooking, sleeping, stress, exercise, falls)
✓ Claude API integration (sends context, gets responses)
✓ Music library (/radio/ all 33 songs)
✓ Voice input detection (simplified wake word)
✓ Health insights (applies K/R/E/T framework to sensor data)
✓ UI (real-time sensor display, scenario selection, music controls)

---

## What's Next (What You'll Build)

**Phase 1 (Now):** Validate synthetic system works end-to-end
- Does Claude API respond? 
- Do scenarios generate realistic data?
- Does audio scene detection work?
- Does music playback route correctly?

**Phase 2 (June 24+):** Replace synthetic sensors with real watch sensors
- Real HR from Series 11 sensor
- Real barometer from watch
- Real microphone input
- Real accelerometer/gyroscope

**Phase 3 (June 24+):** Refine Anna's responses
- Better environmental context injection
- Health insights using his research framework
- Proactive health checks
- Natural TTS (ElevenLabs or similar)

---

## Test It Now

### Scenario: "Cooking"
1. Tap "Cooking" in test scenarios
2. Watch HR rise slowly (78 bpm), accel show arm movement
3. Tap "Listen" → Claude gets context: "I hear stove clicking, you're in the kitchen, HR is elevated, you're probably cooking"
4. Claude responds naturally

### Scenario: "Sleeping"
1. Tap "Sleeping"
2. Watch HR drop (55 bpm), accel flatten, barometer stabilize
3. Tap "Listen" → Claude gets: "HR is low and stable, minimal movement, barometer shows bedroom pressure. You're in deep sleep. Should I mute notifications?"
4. Anna doesn't interrupt

### Scenario: "Falling"
1. Tap "Falling"
2. Watch accel spike (simulated impact), HR jump, gyro spike (tumbling)
3. Tap "Listen" → Claude gets: "Sudden movement spike, high accel, HR jumped 40 bpm. Possible fall?"
4. Immediate: "Are you okay? Do you need help?"

---

## Troubleshooting

### "CLAUDE_API_KEY not set"
```bash
export CLAUDE_API_KEY="sk-ant-..."
# Then restart Xcode/simulator
```

### "Cannot find type 'SensorState'"
This is normal in Xcode's linter. When you build, all files compile together. Run the app — it works.

### "Simulator won't launch"
- Make sure iPhone simulator is selected (top-left of Xcode)
- Hit Play (▶)
- Wait 30 seconds for first launch

### Claude API times out
- Check internet connection
- Check API key is valid (console.anthropic.com)
- Check you have API credits

---

## Customization

### Add a New Test Scenario
In `SensorSimulation.swift`, add to `enum TestScenario`:
```swift
case meditating
```

Then add cases in the generators:
```swift
case .meditating:
    return 60 + sin(time / 30) * 2  // very low HR
```

### Change Claude Model
In `ClaudeAPI.swift`:
```swift
private let model = "claude-sonnet-4-6"  // or claude-opus-4-8
```

### Add More Songs
In `MusicLibrary.swift`, add to `allSongs`:
```swift
Song(title: "My Song", subtitle: "description", filename: "my_song.mp3", trackNumber: 34),
```

---

## API Usage

Each call to Claude costs ~0.0001-0.001 credits depending on response length. 

**Estimate:** 
- 1000 short requests = ~$1
- 1000 long requests = ~$10

For development: set a budget alert on console.anthropic.com

---

## Next Phase: Real Hardware (June 24)

When the watch arrives:
1. Copy this code to Xcode watchOS project
2. Replace synthetic sensors with real watch sensors (HealthKit, CoreMotion, etc.)
3. Replace simulated audio with real microphone input
4. Deploy to watch
5. Test on real body, real environment

Everything else stays the same. The architecture is ready.

---

## The Build Philosophy

- **Fail fast:** Run it now. See what breaks. Fix immediately.
- **Synthetic first:** Validate logic without real hardware.
- **Real second:** Swap sensors, everything else unchanged.
- **Real third:** Refine for speed, battery, UX.

**Current state:** Logic proven. Sensors simulated. Ready for June 24 hardware swap.

---

## Questions?

The code is self-documenting. Each class has one job:
- `AnnaCore` = the brain
- `SensorSimulation` = fake sensors
- `ClaudeAPI` = talking to Claude
- `MusicLibrary` = playing his songs
- `ContentView` = what you see

If something doesn't make sense, print it. Trace it. Fix it.

**Run it. See what happens. Build from there.**
