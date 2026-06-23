import Foundation

/// begump.com relay — Mac Mini ↔ iPhone ↔ Watch when LAN isn't enough.
/// Music already streams from begump CDN. Tools + memory sync can use the same edge eventually.
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
        BEGUMP BRIDGE (Mac ↔ wrist relay):
        - Jim's computer (Mac Mini) runs heavy tools locally when on LAN.
        - When LAN fails or watch needs computer without iPhone in pocket: begump.com relays.
        - Music already uses begump CDN (same origin family as site).
        - Future paths on \(relayBase):
          /tool/{name} — prime, fold, compile from Mac
          /sync/life-memory — watch snapshot when phone is away
          /sync/health — health substrate
          /watch/message — Hey Anna round-trip via cloud edge
        - Jim-only. Air-gapped writes still require "remember" on any path.
        - v1: direct LAN (iPhone settings). v2: begump fallback. v3: watch talks to begump when phone sleeping.
        """
    }
}