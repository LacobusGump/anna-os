import Combine
import Foundation
#if os(iOS)
import UIKit
#endif

final class PhoneBrain: ObservableObject {
    @Published var watchConnected = false
    @Published var lastResponse = ""
    @Published var isProcessing = false
    @Published var apiKey: String = KeychainHelper.loadAPIKey()
    @Published var macHost: String = KeychainHelper.loadMacHost()
    @Published var healthRecords: String = JimHealthProfile.shared.healthRecordsText
    @Published var mc1rNotes: String = JimHealthProfile.shared.mc1rGenotypeNotes
    @Published var bloodType: String = JimHealthProfile.shared.bloodType
    @Published var lifeMemoryCount: Int = LifeMemory.shared.count
    @Published var lifeNotesCount: Int = LifeNotes.shared.count
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
    @Published var shRecordCount: Int = ShLayer.shared.recordCount
    @Published var shCompanionEnabled: Bool = ShLayer.shared.companionEnabled
    @Published var shMessage: String = ""
    @Published private(set) var shContextCache: String = ""

    private let claude = ClaudeAPI()
    private let shLayer = ShLayer.shared
    private let coupling = CouplingLicense.shared
    private let health = JimHealthProfile.shared
    private let lifeMemory = LifeMemory.shared
    private let lifeNotes = LifeNotes.shared
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
        if shLayer.companionEnabled {
            ShCompanion.shared.start()
        }
        refreshShContext()
        #endif
    }

    func setShCompanion(_ on: Bool) {
        ShCompanion.shared.setEnabled(on)
        shCompanionEnabled = shLayer.companionEnabled
        shMessage = on ? "sh companion on — Face Presence gates private captures." : "sh companion off."
    }

    func captureShPhoto(_ image: UIImage) {
        ShCompanion.shared.captureWithJim(from: image, hint: siteContext.currentSite)
        shRecordCount = shLayer.recordCount
        shMessage = "Photo with you → info.sh encrypted."
        refreshShContext()
    }

    private func refreshShContext() {
        shLayer.recentSummaries { [weak self] block in
            self?.shContextCache = block
        }
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
        health.updateBloodType(bloodType)
        let summary = health.summaryForWatchSync()
        watch.send(AnnaMessage(type: .syncMemory, payload: summary))
    }

    private func handleWatchMessage(_ message: AnnaMessage) {
        watchConnected = watch.isWatchReachable

        switch message.type {
        case .askClaude:
            let utterance = message.userUtterance ?? message.payload
            if let mirror = AnnaBond.mirrorIfJimSignature(utterance) {
                watch.send(AnnaMessage(type: .claudeResponse, payload: mirror))
                return
            }
            #if os(iOS)
            if utterance.lowercased().contains("hm") {
                HmConfirm.shared.registerPulse()
            }
            #endif
            processClaudeRequest(
                message.payload,
                learnedContext: message.context ?? "",
                userUtterance: utterance
            )

        case .throwTrust, .bridgeThrow:
            processThrow(
                payload: message.payload,
                learnedContext: message.context ?? "",
                userUtterance: message.userUtterance ?? message.payload,
                viaBridge: message.type == .bridgeThrow
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
            syncLifeNotesToWatch()

        case .syncMemory, .syncLifeMemory, .syncLifeNotes, .throwAck:
            break

        default:
            break
        }
    }

    private func processThrow(payload: String, learnedContext: String, userUtterance: String, viaBridge: Bool = false) {
        isProcessing = true
        let req = ThrowRequest.decodePayload(payload)
            ?? ThrowTrust.parse(userUtterance, site: siteContext.currentSite)
        currentSite = siteContext.currentSite

        var toolInput = [
            "utterance": req.utterance,
            "intention": req.intention.rawValue,
            "site": req.site,
            "trust": req.trustMode ? "jim" : "ask",
            "bridge": viaBridge ? "phone" : "direct",
            "layers": BridgeLayer.syncLayers,
        ] as [String: Any]
        let inputJSON = (try? JSONSerialization.data(withJSONObject: toolInput))
            .flatMap { String(data: $0, encoding: .utf8) } ?? req.utterance

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let result = self.tools.runTool(.throwTrust, input: inputJSON)
            let ack = ThrowTrust.wristAck(
                intention: req.intention,
                macResult: result.status == "success" ? result.result : nil
            )
            DispatchQueue.main.async {
                self.isProcessing = false
                self.lastResponse = ack
                self.watch.send(AnnaMessage(type: .throwAck, payload: ack))
            }
        }
    }

    private func processClaudeRequest(_ context: String, learnedContext: String, userUtterance: String) {
        isProcessing = true
        let key = KeychainHelper.loadAPIKey()
        let memoryQuery = userUtterance.isEmpty ? learnedContext : userUtterance
        let rememberIntent = LifeMemory.hasRememberIntent(userUtterance)
        let transcriptQuery = LifeNotes.hasTranscriptQuery(userUtterance)
        let shQuery = ShLayer.hasShQuery(userUtterance)
        let site = siteContext.currentSite
        currentSite = site

        if !userUtterance.isEmpty {
            lifeNotes.recordJimUtterance(userUtterance, contextLabel: learnedContext)
            if LifeNotes.hasNoteCaptureIntent(userUtterance) {
                lifeNotes.ingestQuotedSpeech(from: userUtterance)
            }
            lifeNotesCount = lifeNotes.count
        }

        var fullContext = JimProfile.systemPreamble()
            + "\n\n---\n\n"
            + LifeMemory.claudeInstructions
            + "\n\n"
            + LifeNotes.claudeInstructions
            + "\n\n"
            + siteContext.contextBlock()
            + "\n\n"
            + callContext.contextBlock()
            + "\n\n"
            + lifeMemory.contextBlock(for: memoryQuery, site: site)
            + "\n\n"
            + lifeMemory.inventoryBlock(site: site)
            + "\n\n"
            + (transcriptQuery ? lifeNotes.contextBlock(for: userUtterance, site: site) : lifeNotes.contextBlock(for: memoryQuery, site: site))
            + "\n\n"
            + BegumpBridge.contextBlock()
            + "\n\n"
            + ThrowTrust.contextBlock()
            + "\n\n"
            + ShLayer.claudeInstructions
            + "\n\n"
            + CouplingJudge.shared.contextBlock()
            + "\n\n"
            + BridgeLayer.contextBlock()
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

        if shQuery {
            shLayer.recentSummaries { [weak self] block in
                guard let self else { return }
                self.shContextCache = block
                self.askClaudeWithContext(fullContext + "\n\n" + block, key: key,
                                          rememberIntent: rememberIntent, userUtterance: userUtterance)
            }
            return
        }

        askClaudeWithContext(fullContext, key: key, rememberIntent: rememberIntent, userUtterance: userUtterance)
    }

    private func askClaudeWithContext(_ fullContext: String, key: String, rememberIntent: Bool, userUtterance: String) {
        claude.askClaude(context: fullContext, apiKey: key) { [weak self] result in
            guard let self else { return }
            DispatchQueue.main.async {
                self.isProcessing = false
                switch result {
                case .success(let response):
                    let cleaned = self.lifeMemory.ingestFromResponse(response, allowStore: rememberIntent)
                    self.lifeMemoryCount = self.lifeMemory.count
                    self.lifeNotes.recordAnnaReply(cleaned, replyingTo: userUtterance)
                    self.lifeNotesCount = self.lifeNotes.count
                    self.egressCount = NetworkGuard.recentEgressCount
                    self.syncLifeMemoryToWatch()
                    self.syncLifeNotesToWatch()
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
        lifeNotes.recordCallNotes(lastCallNotes, contact: callContext.contactName)
        lifeNotesCount = lifeNotes.count
        syncLifeNotesToWatch()
        memoryMessage = "Call logged — verbatim in Life Notes."
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

    private func syncLifeNotesToWatch() {
        guard lifeNotes.count > 0 else { return }
        watch.send(AnnaMessage(type: .syncLifeNotes, payload: lifeNotes.jsonSnapshot()))
    }
}