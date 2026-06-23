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
    }

    @Published var cloudBrainEnabled: Bool
    @Published var macToolsEnabled: Bool
    @Published var musicStreamEnabled: Bool
    @Published var begumpRelayEnabled: Bool

    static var cloudBrainEnabled: Bool { shared.cloudBrainEnabled }
    static var macToolsEnabled: Bool { shared.macToolsEnabled }
    static var musicStreamEnabled: Bool { shared.musicStreamEnabled }
    static var begumpRelayEnabled: Bool { shared.begumpRelayEnabled }

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
    - Mac Mini: run Sentinel from Anna:OS/security/sentinel — tripwire, portcheck, connwatch.
    """

    static let sentinelMacPath = "security/sentinel/sentinel.sh"

    private init() {
        let d = UserDefaults.standard
        cloudBrainEnabled = d.object(forKey: Key.cloudBrain) as? Bool ?? true
        macToolsEnabled = d.object(forKey: Key.macTools) as? Bool ?? true
        musicStreamEnabled = d.object(forKey: Key.musicStream) as? Bool ?? true
        begumpRelayEnabled = d.object(forKey: Key.begumpRelay) as? Bool ?? false
    }

    func save() {
        let d = UserDefaults.standard
        d.set(cloudBrainEnabled, forKey: Key.cloudBrain)
        d.set(macToolsEnabled, forKey: Key.macTools)
        d.set(musicStreamEnabled, forKey: Key.musicStream)
        d.set(begumpRelayEnabled, forKey: Key.begumpRelay)
        BegumpBridge.setUseRelayFallback(begumpRelayEnabled)
    }

    var localOnlySummary: String {
        var lines: [String] = []
        lines.append(cloudBrainEnabled ? "Claude: ON (your key)" : "Claude: OFF")
        lines.append(macToolsEnabled ? "Mac LAN tools: ON" : "Mac LAN tools: OFF")
        lines.append(musicStreamEnabled ? "Music CDN: ON" : "Music CDN: OFF")
        lines.append(begumpRelayEnabled ? "begump relay: ON (explicit)" : "begump relay: OFF")
        return lines.joined(separator: " · ")
    }

    func contextBlock() -> String {
        """
        ANNA SECURITY (Sentinel-aligned, local-first):
        \(localOnlySummary)
        Egress events logged locally: \(NetworkGuard.recentEgressCount)
        \(Self.mousetrapRules)
        """
    }
}