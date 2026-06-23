import Foundation
import Combine

final class PhoneBrain: ObservableObject {
    @Published var watchConnected = false
    @Published var lastResponse = ""
    @Published var isProcessing = false
    @Published var apiKey: String = KeychainHelper.loadAPIKey()
    @Published var macHost: String = KeychainHelper.loadMacHost()

    private let claude = ClaudeAPI()
    private let tools = ToolAccess()
    private let music = MusicStreamPlayer()
    private let speech = SpeechRouter()
    private let watch: WatchMessaging

    init(watch: WatchMessaging = WatchConnectivityServer()) {
        self.watch = watch
        watch.onMessage = { [weak self] message in
            self?.handleWatchMessage(message)
        }
        watchConnected = watch.isWatchReachable
    }

    func saveSettings() {
        KeychainHelper.saveAPIKey(apiKey)
        KeychainHelper.saveMacHost(macHost)
    }

    private func handleWatchMessage(_ message: AnnaMessage) {
        watchConnected = watch.isWatchReachable

        switch message.type {
        case .askClaude:
            processClaudeRequest(message.payload, context: message.context ?? "")

        case .playMusic:
            music.play(filename: message.payload)
            watch.send(AnnaMessage(
                type: .musicState,
                songTitle: message.songTitle,
                isPlaying: true
            ))

        case .pauseMusic:
            music.pause()
            watch.send(AnnaMessage(type: .musicState, isPlaying: false))

        case .phoneStatus:
            watchConnected = message.payload == "watch_ready" || watch.isWatchReachable
            watch.send(AnnaMessage(type: .phoneStatus, payload: "connected"))

        default:
            break
        }
    }

    private func processClaudeRequest(_ context: String, learnedContext: String) {
        isProcessing = true
        let key = KeychainHelper.loadAPIKey()
        let fullContext = JimProfile.systemPreamble() + "\n\n---\n\n" + context

        claude.askClaude(context: fullContext, apiKey: key) { [weak self] result in
            guard let self else { return }
            DispatchQueue.main.async {
                self.isProcessing = false
                switch result {
                case .success(let response):
                    let enriched = self.enrichWithTools(response, query: context, learned: learnedContext)
                    self.lastResponse = enriched
                    self.watch.send(AnnaMessage(type: .claudeResponse, payload: enriched))

                case .failure(let error):
                    let msg = error.localizedDescription
                    self.lastResponse = msg
                    self.watch.send(AnnaMessage(type: .error, payload: msg))
                }
            }
        }
    }

    private func enrichWithTools(_ response: String, query: String, learned: String) -> String {
        let selected = tools.selectTools(for: query, context: learned)
        guard let tool = selected.first else { return response }
        let result = tools.runTool(tool, input: query)
        guard result.status == "success" else { return response }
        return response + "\n[\(result.tool)] \(result.result)"
    }

    func testConnection() {
        watch.send(AnnaMessage(type: .phoneStatus, payload: "connected"))
    }
}