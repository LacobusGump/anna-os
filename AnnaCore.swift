import Foundation
import AVFoundation
import Combine

class AnnaCore: NSObject, ObservableObject {
    // MARK: - UI State
    @Published var isListening = false
    @Published var currentResponse = ""
    @Published var sensorState = SensorState()
    @Published var nowPlaying: Song?
    @Published var isPlaying = false

    // MARK: - Audio Calibration State
    @Published var contextGuesses: [ContextGuess] = []  // Top 3 guesses: "cooking", "coding", "sleeping"
    @Published var audioMemoryCount: Int = 0  // How many labeled audio samples learned

    private var sensorEngine: SensorSimulation
    private var claudeAPI: ClaudeAPI
    private var audioRouter: AudioRouter
    private var musicLibrary: MusicLibrary
    private var memoryContext: MemoryContext
    private var audioMemory: AudioMemory = AudioMemory()  // NEW: stores labeled audio
    private var toolAccess: ToolAccess = ToolAccess()  // NEW: tool integration

    private var listenTimer: Timer?
    private var sensorUpdateTimer: Timer?
    private var calibrationTimer: Timer?  // NEW: periodic guessing

    override init() {
        self.sensorEngine = SensorSimulation()
        self.claudeAPI = ClaudeAPI()
        self.audioRouter = AudioRouter()
        self.musicLibrary = MusicLibrary()
        self.memoryContext = MemoryContext()

        super.init()

        startSensorSimulation()
        startAudioCalibration()  // NEW: always guessing context
    }

    // MARK: - Audio Calibration (Primary Loop)

    private func startAudioCalibration() {
        calibrationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.captureAndGuessContext()
        }
    }

    private func captureAndGuessContext() {
        let audioSample = sensorEngine.getAudioSample()
        let currentContext = sensorState.inferContext()

        // Generate top 3 guesses based on audio + past labels
        let guesses = audioMemory.generateGuesses(
            audio: audioSample,
            sensorContext: currentContext
        )

        DispatchQueue.main.async {
            self.contextGuesses = guesses
            self.audioMemoryCount = self.audioMemory.labeledSamples.count
        }
    }

    func confirmContext(guess: ContextGuess, confirmed: Bool) {
        let audioSample = sensorEngine.getAudioSample()

        if confirmed {
            // Store labeled audio in memory
            audioMemory.recordLabel(
                audio: audioSample,
                label: guess.label,
                confidence: guess.confidence,
                sensors: sensorState
            )

            // Update Claude context with new learning
            memoryContext.recordLearning(label: guess.label, sensors: sensorState)

            // Update music based on context if needed
            if shouldAutoPlayMusic(context: guess.label) {
                recommendMusic(for: guess.label)
            }
        } else {
            // Correction: user saw something different
            audioMemory.recordCorrection(
                audio: audioSample,
                userLabel: "other",
                algoGuess: guess.label
            )
        }

        DispatchQueue.main.async {
            self.audioMemoryCount = self.audioMemory.labeledSamples.count
        }
    }

    // MARK: - Public Interface (Voice Interaction)

    func startListening() {
        isListening = true
        listenTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.processAudio()
        }
    }

    func stopListening() {
        isListening = false
        listenTimer?.invalidate()
    }

    private func processAudio() {
        let audioSample = sensorEngine.getAudioSample()

        // Detect wake word "Anna"
        if audioSample.containsWakeWord {
            handleWakeWord()
        }
    }

    private func handleWakeWord() {
        stopListening()

        // Get context from learned patterns + sensors
        let learnedContext = audioMemory.getMostLikelyContext()
        let sensorContext = sensorState.inferContext()
        let context = memoryContext.buildContext(
            sensors: sensorState,
            learned: learnedContext,
            audioMemory: audioMemory
        )

        // Send to Claude with full context
        claudeAPI.askClaude(context: context) { [weak self] response in
            DispatchQueue.main.async {
                // Check if tools should be used
                let toolsToUse = self?.toolAccess.selectTools(for: context, context: learnedContext) ?? []
                var enrichedResponse = response

                if !toolsToUse.isEmpty {
                    // Run tools and augment response
                    for tool in toolsToUse.prefix(1) {  // Start with top tool
                        let result = self?.toolAccess.runTool(tool, input: context)
                        if let result = result, result.status == "success" {
                            enrichedResponse += "\n[Tool: \(result.tool)] \(result.result)"
                        }
                    }
                }

                self?.currentResponse = enrichedResponse
                self?.audioRouter.speak(enrichedResponse)
            }
        }
    }

    // MARK: - Music (Informed by Learned Context)

    func playSong(named title: String) {
        if let song = musicLibrary.findSong(title) {
            nowPlaying = song
            isPlaying = true
            audioRouter.play(song)
        }
    }

    func playAlbum() {
        if let firstSong = musicLibrary.allSongs.first {
            playSong(named: firstSong.title)
        }
    }

    func recommendMusic(for context: String) {
        // Select music based on learned patterns
        let song: Song?

        switch context {
        case "coding":
            song = musicLibrary.findSong("The Radio")  // focus track
        case "sleeping":
            song = musicLibrary.findSong("Tinnitus Healing")  // sleep track
        case "cooking":
            song = musicLibrary.findSong("coupled_dynamics_remix")  // energy
        default:
            song = nil
        }

        if let song = song {
            playSong(named: song.title)
        }
    }

    func pause() {
        isPlaying = false
        audioRouter.pause()
    }

    func skip() {
        if let current = nowPlaying,
           let currentIndex = musicLibrary.allSongs.firstIndex(of: current),
           currentIndex + 1 < musicLibrary.allSongs.count {
            playSong(named: musicLibrary.allSongs[currentIndex + 1].title)
        }
    }

    // MARK: - Sensor Processing

    private func startSensorSimulation() {
        sensorUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateSensors()
        }
    }

    private func updateSensors() {
        let state = sensorEngine.nextSampleState()
        DispatchQueue.main.async {
            self.sensorState = state
        }
    }

    // MARK: - Helpers

    private func shouldAutoPlayMusic(context: String) -> Bool {
        return context == "coding" || context == "sleeping"
    }

    private func calculateCoupling(hr: Double, accel: Double) -> Double {
        let hrVariance = abs(hr - 72.0) / 72.0
        let accelMagnitude = abs(accel)
        return min(1.0, (hrVariance + accelMagnitude) / 2.0)
    }

    private func calculateSynchronization(hr: Double) -> Double {
        let deviation = abs(hr - 72.0)
        return max(0.0, 1.0 - (deviation / 72.0))
    }
}

// MARK: - Models

struct SensorState {
    var heartRate: Double = 72.0
    var barometer: Double = 101325.0  // pascals
    var acceleration: Double = 0.0
    var gyroscope: Double = 0.0
    var audioLevel: Double = 0.0
    var isSleeping: Bool = false
    var timestamp: Date = Date()

    func inferContext() -> String {
        // Quick inference from sensors for initial guess
        if isSleeping {
            return "sleeping"
        } else if heartRate > 100 && acceleration > 0.5 {
            return "exercising"
        } else if heartRate > 85 && acceleration < 0.1 {
            return "stressed"
        } else if acceleration > 1.5 {
            return "falling"
        } else {
            return "quiet"
        }
    }
}

struct AudioSample {
    var waveform: [Double]
    var spectrum: [Double]
    var containsWakeWord: Bool = false

    func detectEnvironment() -> String {
        // Detect: stove, fridge, water, breathing, etc.
        let dominant = spectrum.max() ?? 0

        if dominant > 0.8 { return "stove" }
        if dominant > 0.5 { return "fridge" }
        if dominant > 0.2 { return "water" }
        return "quiet"
    }
}
