import Foundation

/// Egress whitelist — no mousetrap. Nothing leaves the device unless Jim explicitly allowed it.
enum NetworkGuard {
    enum EgressKind: String {
        case claude
        case macToolLAN
        case begumpRelay
        case musicCDN
        case securityPolicy
        case denied
    }

    private static let logURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("anna_egress.log")
    }()

    static func isAllowed(_ url: URL) -> Bool {
        classify(url) != .denied
    }

    static func isSecurityPolicyURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let path = url.path
        if host == "license.begump.com" && path == "/validate" { return true }
        if host == "begump.com" && path == "/anna/security-policy.json" { return true }
        return false
    }

    static func classify(_ url: URL) -> EgressKind {
        guard let host = url.host?.lowercased() else { return .denied }

        if isSecurityPolicyURL(url) {
            return .securityPolicy
        }

        if host == "api.anthropic.com" {
            return AnnaSecurity.cloudBrainEnabled ? .claude : .denied
        }

        if host.hasSuffix("jsdelivr.net") || host == "cdn.jsdelivr.net" {
            return AnnaSecurity.musicStreamEnabled ? .musicCDN : .denied
        }

        if host == "begump.com" || host.hasSuffix(".begump.com") {
            return BegumpBridge.useRelayFallback && AnnaSecurity.begumpRelayEnabled ? .begumpRelay : .denied
        }

        if AnnaSecurity.isEgressHostAllowed(host) {
            if host.contains("anthropic") {
                return AnnaSecurity.cloudBrainEnabled ? .claude : .denied
            }
            if host.contains("jsdelivr") {
                return AnnaSecurity.musicStreamEnabled ? .musicCDN : .denied
            }
        }

        if isLocalLAN(host) {
            return AnnaSecurity.macToolsEnabled ? .macToolLAN : .denied
        }

        return .denied
    }

    static func logEgress(url: URL, kind: EgressKind) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(kind.rawValue) \(url.host ?? "?")\(url.path)\n"
        guard let data = line.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: logURL.path),
           let handle = try? FileHandle(forWritingTo: logURL) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: logURL)
        }
    }

    static var recentEgressCount: Int {
        guard let text = try? String(contentsOf: logURL, encoding: .utf8) else { return 0 }
        return text.components(separatedBy: "\n").filter { !$0.isEmpty }.count
    }

    static func isLocalLAN(_ host: String) -> Bool {
        if host == "localhost" || host == "127.0.0.1" || host == "::1" { return true }
        if host.hasPrefix("192.168.") || host.hasPrefix("10.") { return true }
        if host.hasPrefix("172.") {
            let parts = host.split(separator: ".")
            if parts.count > 1, let second = Int(parts[1]), second >= 16 && second <= 31 { return true }
        }
        return false
    }

    static func validateMacHost(_ hostString: String) -> Bool {
        guard let url = URL(string: hostString), let h = url.host else { return false }
        return isLocalLAN(h)
    }
}