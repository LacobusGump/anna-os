import Foundation
import Combine
import WatchKit

final class AnnaCore: NSObject, ObservableObject {
    @Published var interactionMode: InteractionMode = .calibrating
    @Published var isWakeWordListening = true
    @Published var currentResponse = ""
    @Published var proactiveAlert = ""
    @Published var sensorState = SensorState()
    @Published var nowPlaying: Song?
    @Published var isPlaying = false
    @Published var phoneConnected = false

    @Published var contextGuesses: [ContextGuess] = []
    @Published var audioMemoryCount: Int = 0
    @Published var pendingPrompt: ContextGuess?

    private let sensorEngine: SensorProviding
    private let audioEngine: AudioCapturing
    private let audioRouter = WatchAudioRouter()
    private let musicLibrary = MusicLibrary()
    private let memoryContext = MemoryContext()
    private let audioMemory = AudioMemory()
    private let phone: PhoneMessaging

    private var calibrationTimer: Timer?
    private var extendedSession: WKExtendedRuntimeSession?

    init(
        sensorEngine: SensorProviding = HealthSensorEngine(),
        audioEngine: AudioCapturing = AudioCaptureEngine(),
        phone: PhoneMessaging = WatchConnectivityClient()
    ) {
        self.sensorEngine = sensorEngine
        self.audioEngine = audioEngine
        self.phone = phone
        super.init()

        sensorEngine.onStateUpdate = { [weak self] state in
            DispatchQueue.main.async { self?.sensorState = state }
        }

        audioEngine.onWakeWord = { [weak self] in
            self?.beginConversation()
        }

        phone.onMessage = { [weak self] message in
            self?.handlePhoneMessage(message)
        }

        start()
    }

    private func start() {
        sensorEngine.start()
        try? audioEngine.start()
        startExtendedRuntime()
        startCalibrationLoop()

        phone.send(AnnaMessage(type: .phoneStatus, payload: "watch_ready"))
        phoneConnected = phone.isPhoneReachable
    }

    private func startExtendedRuntime() {
        let session = WKExtendedRuntimeSession()
        session.start()
        extendedSession = session
    }

    private func startCalibrationLoop() {
        calibrationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.captureAndGuessContext()
        }
        audioMemoryCount = audioMemory.labeledSamples.count
    }

    private func captureAndGuessContext() {
        guard interactionMode == .calibrating else { return }
        let audioSample = audioEngine.currentSample()
        let guesses = audioMemory.generateGuesses(
            audio: audioSample,
            sensorContext: sensorState.inferContext()
        )
        contextGuesses = guesses
        pendingPrompt = guesses.first
        audioMemoryCount = audioMemory.labeledSamples.count
    }

    func confirmContext(guess: ContextGuess, confirmed: Bool) {
        interactionMode = .calibrating
        proactiveAlert = ""
        let audioSample = audioEngine.currentSample()

        if confirmed {
            audioMemory.recordLabel(
                audio: audioSample,
                label: guess.label,
                confidence: guess.confidence,
                sensors: sensorState
            )
            memoryContext.recordLearning(label: guess.label, sensors: sensorState)
            if shouldAutoPlayMusic(context: guess.label) {
                recommendMusic(for: guess.label)
            }
        } else {
            audioMemory.recordCorrection(
                audio: audioSample,
                userLabel: "other",
                algoGuess: guess.label
            )
        }

        audioMemoryCount = audioMemory.labeledSamples.count
        pendingPrompt = nil
    }

    func beginConversation() {
        interactionMode = .conversing
        proactiveAlert = ""
        pendingPrompt = nil
        currentResponse = "…"

        let learnedContext = audioMemory.getMostLikelyContext()
        let context = memoryContext.buildContext(
            sensors: sensorState,
            learned: learnedContext,
            audioMemory: audioMemory
        )

        phone.send(AnnaMessage(type: .askClaude, payload: context, context: learnedContext))
    }

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

    private func handlePhoneMessage(_ message: AnnaMessage) {
        phoneConnected = phone.isPhoneReachable

        switch message.type {
        case .claudeResponse:
            currentResponse = message.payload
            deliverSpeech(message.payload, mode: interactionMode)

        case .speak:
            deliverSpeech(message.payload, mode: interactionMode)

        case .musicState:
            if let title = message.songTitle,
               let song = musicLibrary.findSong(title) {
                nowPlaying = song
            }
            isPlaying = message.isPlaying ?? false

        case .phoneStatus:
            phoneConnected = message.payload == "connected"

        case .error:
            currentResponse = message.payload

        default:
            break
        }
    }

    private func deliverSpeech(_ text: String, mode: InteractionMode) {
        guard mode.maySpeak else { return }
        audioRouter.speak(text)
    }

    func playSong(named title: String) {
        guard let song = musicLibrary.findSong(title) else { return }
        nowPlaying = song
        isPlaying = true
        audioRouter.play(song)
        phone.send(AnnaMessage(type: .playMusic, payload: song.filename, songTitle: song.title))
    }

    func playAlbum() {
        if let first = musicLibrary.allSongs.first {
            playSong(named: first.title)
        }
    }

    func recommendMusic(for context: String) {
        let song: Song?
        switch context {
        case "coding": song = musicLibrary.findSong("Coupled Dynamics")
        case "sleeping": song = musicLibrary.findSong("hm.<3")
        case "cooking": song = musicLibrary.findSong("Installation Hum")
        default: song = nil
        }
        if let song { playSong(named: song.title) }
    }

    func pause() {
        isPlaying = false
        audioRouter.pause()
        phone.send(AnnaMessage(type: .pauseMusic))
    }

    func skip() {
        guard let current = nowPlaying,
              let idx = musicLibrary.allSongs.firstIndex(of: current),
              idx + 1 < musicLibrary.allSongs.count else { return }
        playSong(named: musicLibrary.allSongs[idx + 1].title)
    }

    private func shouldAutoPlayMusic(context: String) -> Bool {
        context == "coding" || context == "sleeping"
    }
}