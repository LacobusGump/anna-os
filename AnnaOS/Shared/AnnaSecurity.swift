import Foundation

/// Anna security policy — Sentinel principles on wrist + phone.
/// Local-only default. No telemetry. No cloud memory. No mousetrap opt-outs buried in settings.
final class AnnaSecurity: ObservableObject {
    static let shared = AnnaSecurity()

    private enum Key {
        static let cloudBrain = "anna_sec_cloud_brain"
        static let macTools = "anna_sec_mac_tools"
        static let musicStream = "anna_sec_music_stream"
        static let begumpRelay = "anna_sec_begump_relay"
        static let policyApplied = "anna_sec_policy_applied"
    }

    @Published var cloudBrainEnabled: Bool
    @Published var macToolsEnabled: Bool
    @Published var musicStreamEnabled: Bool
    @Published var begumpRelayEnabled: Bool

    @Published private(set) var policyVersion: String = "0"
    @Published private(set) var policySource: String = "bundled"
    @Published private(set) var anthropicModel: String = "claude-sonnet-4-20250514"
    @Published private(set) var anthropicMaxTokens: Int = 1024
    @Published private(set) var rememberConsentRequired: Bool = true
    @Published private(set) var remoteMousetrapRules: String?

    private(set) var allowedEgressHosts: [String] = [
        "api.anthropic.com",
        "cdn.jsdelivr.net"
    ]

    static var cloudBrainEnabled: Bool { shared.cloudBrainEnabled }
    static var macToolsEnabled: Bool { shared.macToolsEnabled }
    static var musicStreamEnabled: Bool { shared.musicStreamEnabled }
    static var begumpRelayEnabled: Bool { shared.begumpRelayEnabled }
    static var anthropicModel: String { shared.anthropicModel }
    static var anthropicMaxTokens: Int { shared.anthropicMaxTokens }

    static let mousetrapRules = """
    MOUSETRAP AVOIDANCE (Jim's Sentinel rules on Anna):
    - No telemetry SDKs. No analytics. No crash reporters that phone home.
    - Memories/health never upload by default — device encrypted at rest (Secure Enclave key).
    - Claude is opt-in (your API key). No key = no egress to Anthropic.
    - Mac tools LAN-only (127.0.0.1 / 192.168.x). Reject 0.0.0.0 bindings.
    - begump relay OFF by default — explicit toggle, never auto-enabled.
    - Music CDN separate toggle — jsDelivr only, no account coupling.
    - Remember consent still gates writes even on relay paths.
    - Egress logged locally (~/.anna equivalent) — never sent anywhere.
    - sh layer: info.sh blobs encrypted separately; Face Presence gates read/write; never syncs to watch.
    - Security policy updates via begump.com/anna/security-policy.json — memories never leave device.
    - Mac Mini: run Sentinel from Anna:OS/security/sentinel — tripwire, portcheck, connwatch.
    """

    static let sentinelMacPath = "security/sentinel/sentinel.sh"

    private init() {
        let d = UserDefaults.standard
        cloudBrainEnabled = d.object(forKey: Key.cloudBrain) as? Bool ?? true
        macToolsEnabled = d.object(forKey: Key.macTools) as? Bool ?? true
        musicStreamEnabled = d.object(forKey: Key.musicStream) as? Bool ?? true
        begumpRelayEnabled = d.object(forKey: Key.begumpRelay) as? Bool ?? false
        if let bundled = Self.loadBundledPolicy() {
            applyRemotePolicy(bundled, applyDefaults: !d.bool(forKey: Key.policyApplied))
        }
    }

    private static func loadBundledPolicy() -> SecurityPolicyDocument? {
        guard let url = Bundle.main.url(forResource: "security-policy.default", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SecurityPolicyDocument.self, from: data)
    }

    func save() {
        let d = UserDefaults.standard
        d.set(cloudBrainEnabled, forKey: Key.cloudBrain)
        d.set(macToolsEnabled, forKey: Key.macTools)
        d.set(musicStreamEnabled, forKey: Key.musicStream)
        d.set(begumpRelayEnabled, forKey: Key.begumpRelay)
        BegumpBridge.setUseRelayFallback(begumpRelayEnabled)
    }

    func applyRemotePolicy(_ doc: SecurityPolicyDocument, applyDefaults: Bool = false) {
        policyVersion = doc.version
        policySource = doc.source ?? "remote"

        if let anna = doc.anna {
            if let model = anna.anthropicModel { anthropicModel = model }
            if let tokens = anna.anthropicMaxTokens { anthropicMaxTokens = tokens }
            if let hosts = anna.allowedEgressHosts { allowedEgressHosts = hosts }
            if let consent = anna.rememberConsentRequired { rememberConsentRequired = consent }
            if let rules = anna.mousetrapRules { remoteMousetrapRules = rules }

            if applyDefaults {
                if let v = anna.cloudBrainDefault { cloudBrainEnabled = v }
                if let v = anna.macToolsDefault { macToolsEnabled = v }
                if let v = anna.musicCdnDefault { musicStreamEnabled = v }
                if let v = anna.begumpRelayDefault {
                    begumpRelayEnabled = v
                    BegumpBridge.setUseRelayFallback(v)
                }
                UserDefaults.standard.set(true, forKey: Key.policyApplied)
                save()
            }
        }
    }

    static func isEgressHostAllowed(_ host: String) -> Bool {
        let h = host.lowercased()
        return shared.allowedEgressHosts.contains { allowed in
            let a = allowed.lowercased()
            return h == a || h.hasSuffix(".\(a)")
        }
    }

    var localOnlySummary: String {
        var lines: [String] = []
        lines.append(cloudBrainEnabled ? "Claude: ON (your key)" : "Claude: OFF")
        lines.append(macToolsEnabled ? "Mac LAN tools: ON" : "Mac LAN tools: OFF")
        lines.append(musicStreamEnabled ? "Music CDN: ON" : "Music CDN: OFF")
        lines.append(begumpRelayEnabled ? "begump relay: ON (explicit)" : "begump relay: OFF")
        lines.append("Policy: v\(policyVersion) (\(policySource))")
        return lines.joined(separator: " · ")
    }

    func contextBlock() -> String {
        let rules = remoteMousetrapRules ?? Self.mousetrapRules
        return """
        ANNA SECURITY (Sentinel-aligned, local-first):
        \(localOnlySummary)
        Claude model: \(anthropicModel) · max_tokens: \(anthropicMaxTokens)
        Egress events logged locally: \(NetworkGuard.recentEgressCount)
        \(rules)
        """
    }
}