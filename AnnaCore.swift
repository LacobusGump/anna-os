import Foundation
import AVFoundation
import Combine

class AnnaCore: NSObject, ObservableObject {
    // MARK: - UI State
    @Published var interactionMode: InteractionMode = .calibrating
    @Published var isWakeWordListening = true
    @Published var currentResponse = ""
    @Published var proactiveAlert = ""
    @Published var sensorState = SensorState()
    @Published var nowPlaying: Song?
    @Published var isPlaying = false

    // MARK: - Audio Calibration State (silent — watch face only)
    @Published var contextGuesses: [ContextGuess] = []
    @Published var audioMemoryCount: Int = 0
    @Published var pendingPrompt: ContextGuess?

    private var sensorEngine: SensorSimulation
    private var claudeAPI: ClaudeAPI
    private var audioRouter: AudioRouter
    private var musicLibrary: MusicLibrary
    private var memoryContext: MemoryContext
    private var audioMemory: AudioMemory = AudioMemory()
    private var toolAccess: ToolAccess = ToolAccess()

    private var wakeWordTimer: Timer?
    private var sensorUpdateTimer: Timer?
    private var calibrationTimer: Timer?

    override init() {
        self.sensorEngine = SensorSimulation()
        self.claudeAPI = ClaudeAPI()
        self.audioRouter = AudioRouter()
        self.musicLibrary = MusicLibrary()
        self.memoryContext = MemoryContext()

        super.init()

        startSensorSimulation()
        startPersistentListening()
    }

    // MARK: - Persistent Listening

    /// Always on: calibration loop + wake-word ear. Questions never spoken.
    private func startPersistentListening() {
        calibrationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.captureAndGuessContext()
        }
        wakeWordTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.scanForWakeWord()
        }
        isWakeWordListening = true
    }

    private func captureAndGuessContext() {
        guard interactionMode == .calibrating else { return }

        let audioSample = sensorEngine.getAudioSample()
        let currentContext = sensorState.inferContext()
        let guesses = audioMemory.generateGuesses(
            audio: audioSample,
            sensorContext: currentContext
        )

        DispatchQueue.main.async {
            self.contextGuesses = guesses
            self.pendingPrompt = guesses.first
            self.audioMemoryCount = self.audioMemory.labeledSamples.count
        }
    }

    private func scanForWakeWord() {
        guard isWakeWordListening else { return }
        let audioSample = sensorEngine.getAudioSample()
        if audioSample.containsWakeWord {
            beginConversation()
        }
    }

    func confirmContext(guess: ContextGuess, confirmed: Bool) {
        interactionMode = .calibrating
        proactiveAlert = ""
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
            self.pendingPrompt = nil
        }
    }

    // MARK: - Two-Way Voice (gated)

    /// User said "Hey Anna" — conversation mode. Voice out is allowed.
    func beginConversation() {
        interactionMode = .conversing
        proactiveAlert = ""
        pendingPrompt = nil

        let learnedContext = audioMemory.getMostLikelyContext()
        let context = memoryContext.buildContext(
            sensors: sensorState,
            learned: learnedContext,
            audioMemory: audioMemory
        )

        claudeAPI.askClaude(context: context) { [weak self] response in
            guard let self else { return }
            let toolsToUse = self.toolAccess.selectTools(for: context, context: learnedContext)
            var enrichedResponse = response

            if !toolsToUse.isEmpty {
                for tool in toolsToUse.prefix(1) {
                    let result = self.toolAccess.runTool(tool, input: context)
                    if result.status == "success" {
                        enrichedResponse += "\n[Tool: \(result.tool)] \(result.result)"
                    }
                }
            }

            DispatchQueue.main.async {
                self.currentResponse = enrichedResponse
                self.deliverSpeech(enrichedResponse, mode: .conversing)
            }
        }
    }

    /// Anna interrupts — e.g. "Jim, this person is lying to you." Voice out is allowed.
    func deliverProactiveAlert(_ message: String) {
        interactionMode = .alerting
        proactiveAlert = message
        pendingPrompt = nil
        currentResponse = message
        deliverSpeech(message, mode: .alerting)
    }

    func dismissConversation() {
        interactionMode = .calibrating
        currentResponse = ""
        proactiveAlert = ""
    }

    private func deliverSpeech(_ text: String, mode: InteractionMode) {
        guard mode.maySpeak else { return }
        audioRouter.speak(text)
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
