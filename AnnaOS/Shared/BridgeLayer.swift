import Foundation

/// Bridge layer — Jim · Watch · Phone · M4 · begump.com.
/// No wearable lens. Phone bridges the internet world. M4 vaults throw-away.
enum SymbioTier: String, Codable, CaseIterable {
    case watch
    case phone
    case mac
}

enum BridgeLayer {
    /// Every tier syncs to be throwable — nothing precious on device, all compressible vault.
    static let throwAwaySync = true

    /// Watch solves without lens: intent, notes query, voice, calibration.
    static func watchCanSolve(intention: ThrowIntention, utterance: String) -> Bool {
        switch intention {
        case .life, .knowledge:
            return true
        case .build:
            return !utterance.lowercased().contains("photo")
        case .media, .phone, .data:
            return false
        }
    }

    /// Phone bridges: camera roll, internet, calls, geo, Claude, full world.
    static func phoneMustBridge(intention: ThrowIntention) -> Bool {
        switch intention {
        case .media, .phone, .data:
            return true
        case .build, .knowledge, .life:
            return false
        }
    }

    static func tier(for intention: ThrowIntention) -> SymbioTier {
        if phoneMustBridge(intention: intention) { return .phone }
        return .watch
    }

    static func bridgeAck(intention: ThrowIntention) -> String {
        "Phone bridge — \(intention.rawValue)."
    }

    /// Layers that throw-away sync to Mac vault (no lens required).
    static var syncLayers: [String] {
        [
            "life_notes",
            "life_memory",
            "phone_dcim",
            "call_context",
            "desktop",
            "downloads",
            "throw_intentions",
        ]
    }

    static func contextBlock() -> String {
        SymbioStack.contextBlock()
    }
}