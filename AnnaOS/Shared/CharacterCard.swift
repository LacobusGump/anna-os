import Foundation

/// Layer 1 judgment — one card per inbound fact. Simply complex like a track on Spotify:
/// numerically assigned, one identity surface, not stacked personas.
enum JudgmentVerdict: String, Codable {
    case couple
    case decay
    case reject
}

struct CharacterCard: Codable, Identifiable, Equatable {
    let id: UUID
    var role: String
    var site: String
    var intention: String
    var couplingScore: Double
    var voiceConfidence: Double
    var actionTags: [String]
    var leftHand: Bool
    var verdict: JudgmentVerdict
    var ironyNote: String
    var judgedAt: Date

    init(
        id: UUID = UUID(),
        role: String,
        site: String,
        intention: String = "data",
        couplingScore: Double,
        voiceConfidence: Double = 0,
        actionTags: [String] = [],
        leftHand: Bool = true,
        verdict: JudgmentVerdict,
        ironyNote: String = "",
        judgedAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.site = site.lowercased()
        self.intention = intention
        self.couplingScore = couplingScore
        self.voiceConfidence = voiceConfidence
        self.actionTags = actionTags
        self.leftHand = leftHand
        self.verdict = verdict
        self.ironyNote = ironyNote
        self.judgedAt = judgedAt
    }
}