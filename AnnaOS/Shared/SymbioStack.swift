import Foundation

/// Jim · Watch · Phone · M4 — held together anywhere by begump.com.
enum SymbioNode: String, Codable, CaseIterable {
    case jim
    case watch
    case phone
    case m4
}

enum SymbioStack {
    static let glue = "begump.com"

    static let topology: [(SymbioNode, String)] = [
        (.jim, "Person #1 — throws, trusts, judges. Left hand already there."),
        (.watch, "Narrow brain — intent, voice, sensors, Life Notes query. No lens."),
        (.phone, "Bridge — internet, DCIM, calls, geo, Claude. Best robot for the online world."),
        (.m4, "Vault — M4 Mac Mini, throw-away compress (sfumato, spectral, qdrive)."),
    ]

    static func node(for tier: SymbioTier) -> SymbioNode {
        switch tier {
        case .watch: return .watch
        case .phone: return .phone
        case .mac: return .m4
        }
    }

    /// begump holds the stack when LAN breaks — coupling, policy, relay, music, sync.
    static func contextBlock() -> String {
        let lines = topology.map { "  \($0.0.rawValue): \($0.1)" }.joined(separator: "\n")
        return """
        SYMBIO STACK (four nodes, one glue):
        \(lines)
        GLUE: \(glue) — holds Jim+Watch+Phone+M4 together anywhere.
        - LAN: phone → M4 :8765 (anna tools, throw, quantum)
        - Away: \(BegumpBridge.relayBase) — tools, sync, security policy, music CDN
        - Coupling license recouple pulls policy from \(glue); memories stay on phone
        - Every layer throw-away synced to M4 vault. No wearable lens. Phone bridges the world.
        """
    }
}