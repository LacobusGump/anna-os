import Foundation

/// How Anna talks (and doesn't).
///
/// Calibration = eyes only. Never TTS.
/// Conversation = "Hey Anna" → two-way voice OK.
/// Alert = Anna interrupts for something that matters → voice OK.
enum InteractionMode: String, Codable {
    case calibrating
    case conversing
    case alerting

    var maySpeak: Bool {
        switch self {
        case .calibrating: return false
        case .conversing, .alerting: return true
        }
    }
}