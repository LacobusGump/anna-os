import Foundation
import Combine

final class PhoneBrain: ObservableObject {
    @Published var watchConnected = false
    @Published var lastResponse = ""
    @Published var isProcessing = false
    @Published var apiKey: String = KeychainHelper.loadAPIKey()
    @Published var macHost: String = KeychainHelper.loadMacHost()
    @Published var healthRecords: String = JimHealthProfile.shared.healthRecordsText
    @Published var mc1rNotes: String = JimHealthProfile.shared.mc1rGenotypeNotes
    @Published var lifeMemoryCount: Int = LifeMemory.shared.count
    @Published var quickMemoryLine: String = ""
    @Published var memoryMessage: String = ""
    @Published var lastCallNotes: String = CallContext.shared.lastCallNotes
    @Published var manualSite: String = SiteContext.shared.manualSiteOverride
    @Published var currentSite: String = SiteContext.shared.currentSite
    @Published var useBegumpRelay: Bool = BegumpBridge.useRelayFallback
    @Published var egressCount: Int = NetworkGuard.recentEgressCount
    @Published var licenseKeyInput: String = KeychainHelper.loadLicenseKey()
    @Published var couplingPhase: String = CouplingLicense.shared.phase
    @Published var couplingK: Double = CouplingLicense.shared.K
    @Published var policyVersion: String = AnnaSecurity.shared.policyVersion
    @Published var couplingMessage: String = ""

    private let claude = ClaudeAPI()
    private let coupling = CouplingLicense.shared
    private let health = JimHealthProfile.shared
    private let lifeMemory = LifeMemory.shared
    private let siteContext = SiteContext.shared
    private let callContext = CallContext.shared
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
        AnnaSecurity.shared.begumpRelayEnabled = useBegumpRelay
        #if os(iOS)
        siteContext.startLocationUpdates()
        refreshSecurityPolicy()
        #endif
    }

    func refreshSecurityPolicy() {
        SecurityPolicySync.shared.refreshIfNeeded()
        policyVersion = AnnaSecurity.shared.policyVersion

        guard coupling.activated else {
            couplingMessage = "Local mode — add GUMP key to recouple security policy."
            return
        }

        coupling.recouple { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.couplingPhase = self.coupling.phase
                self.couplingK = self.coupling.K
                self.policyVersion = AnnaSecurity.shared.policyVersion
                switch result {
                case .success:
                    self.couplingMessage = "Recoupled — policy v\(self.policyVersion)"
                case .failure(let error):
                    self.couplingMessage = error.localizedDescription
                }
            }
        }
    }

    func activateLicense() {
        let trimmed = licenseKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard coupling.activate(trimmed) else {
            couplingMessage = "Invalid key — format GUMP-XXXX-XXXX-XXXX"
            return
        }
        licenseKeyInput = trimmed
        couplingPhase = coupling.phase
        couplingK = coupling.K
        couplingMessage = "License activated — recoupling…"
        refreshSecurityPolicy()
    }

    func saveSettings() {
        KeychainHelper.saveAPIKey(apiKey)
        KeychainHelper.saveMacHost(macHost)
        BegumpBridge.setUseRelayFallback(useBegumpRelay)
        AnnaSecurity.shared.begumpRelayEnabled = useBegumpRelay
        AnnaSecurity.shared.save()
    }

    func saveSecurity() {
        let sec = AnnaSecurity.shared
        sec.save()
        useBegumpRelay = sec.begumpRelayEnabled
        BegumpBridge.setUseRelayFallback(useBegumpRelay)
        egressCount = NetworkGuard.recentEgressCount
        memoryMessage = sec.localOnlySummary
    }

    func saveHealthProfile() {
        health.updateHealthRecords(healthRecords)
        health.updateGenotypeNotes(mc1rNotes)
        let summary = health.summaryForWatchSync()
        watch.send(AnnaMessage(type: .syncMemory, payload: summary))
    }

    private func handleWatchMessage(_ message: AnnaMessage) {
        watchConnected = watch.isWatchReachable

        switch message.type {
        case .askClaude:
            processClaudeRequest(
                message.payload,
                learnedContext: message.context ?? "",
                userUtterance: message.userUtterance ?? ""
            )

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
            if !health.healthRecordsText.isEmpty || !health.mc1rGenotypeNotes.isEmpty {
                watch.send(AnnaMessage(type: .syncMemory, payload: health.summaryForWatchSync()))
            }
            syncLifeMemoryToWatch()

        case .syncMemory, .syncLifeMemory:
            break

        default:
            break
        }
    }

    private func processClaudeRequest(_ context: String, learnedContext: String, userUtterance: String) {
        isProcessing = true
        let key = KeychainHelper.loadAPIKey()
        let memoryQuery = userUtterance.isEmpty ? learnedContext : userUtterance
        let rememberIntent = LifeMemory.hasRememberIntent(userUtterance)
        let site = siteContext.currentSite
        currentSite = site

        var fullContext = JimProfile.systemPreamble()
            + "\n\n---\n\n"
            + LifeMemory.claudeInstructions
            + "\n\n"
            + siteContext.contextBlock()
            + "\n\n"
            + callContext.contextBlock()
            + "\n\n"
            + lifeMemory.contextBlock(for: memoryQuery, site: site)
            + "\n\n"
            + lifeMemory.inventoryBlock(site: site)
            + "\n\n"
            + BegumpBridge.contextBlock()
            + "\n\n"
            + AnnaSecurity.shared.contextBlock()
            + "\n\n---\n\n"
            + health.contextBlock()
            + "\n\n---\n\n"
            + context

        if rememberIntent {
            fullContext += "\n\nREMEMBER INTENT DETECTED — Jim asked to store facts. Emit <anna_memory> tags."
        } else {
            fullContext += "\n\nNo remember intent — retrieve only, do not emit memory tags."
        }

        claude.askClaude(context: fullContext, apiKey: key) { [weak self] result in
            guard let self else { return }
            DispatchQueue.main.async {
                self.isProcessing = false
                switch result {
                case .success(let response):
                    let cleaned = self.lifeMemory.ingestFromResponse(response, allowStore: rememberIntent)
                    self.lifeMemoryCount = self.lifeMemory.count
                    self.egressCount = NetworkGuard.recentEgressCount
                    self.syncLifeMemoryToWatch()
                    let enriched = self.enrichWithTools(
                        cleaned,
                        query: userUtterance.isEmpty ? context : userUtterance,
                        learned: learnedContext
                    )
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

    func saveCallContext() {
        callContext.updateNotes(lastCallNotes)
        memoryMessage = "Call context saved."
    }

    func saveManualSite() {
        siteContext.setManualSite(manualSite)
        currentSite = siteContext.currentSite
        memoryMessage = "Site set to \(currentSite)."
    }

    func addQuickMemory() {
        guard lifeMemory.ingestQuickLine(quickMemoryLine) else {
            memoryMessage = "Format: inventory@home.eggs_count=5 or build@work.deck_materials_list=…"
            return
        }
        quickMemoryLine = ""
        lifeMemoryCount = lifeMemory.count
        memoryMessage = "Saved — synced to watch on next ping."
        syncLifeMemoryToWatch()
    }

    private func syncLifeMemoryToWatch() {
        guard lifeMemory.count > 0 else { return }
        watch.send(AnnaMessage(type: .syncLifeMemory, payload: lifeMemory.jsonSnapshot()))
    }
}