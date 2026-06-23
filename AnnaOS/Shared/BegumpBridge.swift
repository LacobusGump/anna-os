import Foundation

/// begump.com — glue for Jim · Watch · Phone · M4 anywhere.
/// LAN when home; relay when not. Music, policy, tools, sync on same edge family.
enum BegumpBridge {
    static let relayBase = "https://begump.com/anna"
    static let musicCDN = "https://cdn.jsdelivr.net/gh/LacobusGump/music2.0@main"
    private static let relayKey = "anna_use_begump_relay"

    enum Endpoint: String {
        case ping
        case tool
        case syncMemory
        case syncLifeMemory
        case syncHealth
        case watchMessage
    }

    static func url(for endpoint: Endpoint, path: String = "") -> URL? {
        var base = relayBase
        if !path.isEmpty && !path.hasPrefix("/") { base += "/" }
        let full = path.isEmpty ? "\(base)/\(endpoint.rawValue)" : "\(base)\(path)"
        return URL(string: full)
    }

    static func toolURL(tool: String) -> URL? {
        url(for: .tool, path: "/\(tool)")
    }

    static var useRelayFallback: Bool {
        UserDefaults.standard.bool(forKey: relayKey)
    }

    static func setUseRelayFallback(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: relayKey)
    }

    /// Human-readable architecture block for Claude context.
    static func contextBlock() -> String {
        """
        BEGUMP GLUE — holds Jim · Watch · Phone · M4 together anywhere:
        - Home: Phone bridges to M4 LAN (:8765 throw/tools, :1370 quantum, :8890 license)
        - Away: \(relayBase) relays same stack — tools, sync, policy, music CDN
        - Paths: /tool/{name} · /sync/life-memory · /sync/health · /watch/message · /security-policy.json
        - Coupling license recouple from license.begump.com — policy only, not memories
        - Relay OFF by default (Jim toggles). Throw-away vault always lands on M4 when reachable.
        """
    }
}