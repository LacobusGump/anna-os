import Foundation

/// Best judge — numerical coupling before anything sticks.
/// Bad memory doesn't couple → reject. Left hand already trusted; right hand builds Anna.
/// Irony: meaning often obvious only after the left held the painting long enough.
final class CouplingJudge {
    static let shared = CouplingJudge()

    /// Below this: fuck a bad memory — it doesn't enter the trusted layer.
    static let coupleThreshold = 0.42
    static let decayThreshold = 0.55

    private init() {}

    func judgeNote(
        verbatim: String,
        speaker: NoteSpeaker,
        site: String,
        voiceConfidence: Double = 0,
        rememberBoost: Bool = false
    ) -> CharacterCard {
        let actions = LifeNotes.extractActions(from: verbatim)
        let intention = ThrowTrust.detectIntention(
            from: verbatim,
            site: site
        ).rawValue
        let score = scoreText(
            verbatim,
            speaker: speaker,
            site: site,
            actions: actions,
            voiceConfidence: voiceConfidence,
            rememberBoost: rememberBoost
        )
        return buildCard(
            role: speaker.rawValue,
            site: site,
            intention: intention,
            score: score,
            voiceConfidence: voiceConfidence,
            actions: actions,
            leftHand: true
        )
    }

    func judgeMemory(
        category: MemoryCategory,
        key: String,
        value: String,
        site: String,
        rememberBoost: Bool = true
    ) -> CharacterCard {
        let text = "\(key) \(value)"
        let actions = LifeNotes.extractActions(from: text)
        let score = scoreText(
            text,
            speaker: .jim,
            site: site,
            actions: actions,
            voiceConfidence: 1.0,
            rememberBoost: rememberBoost,
            categoryBoost: category == .build || category == .inventory || category == .work
        )
        return buildCard(
            role: "jim",
            site: site,
            intention: category.rawValue,
            score: score,
            voiceConfidence: 1.0,
            actions: actions,
            leftHand: false
        )
    }

    func contextBlock() -> String {
        let k = CouplingLicense.shared.K
        """
        JUDGMENT (layer 1 — character card, not stacked identity):
        Every inbound fact gets one card: role, site, intention, coupling score, verdict.
        Simply complex — like a song assigned to Spotify IDs, one surface, best numerical judge.
        couple ≥ \(Self.coupleThreshold) sticks. Below → reject (doesn't couple to Jim's system).
        System K=\(String(format: "%.3f", k)). Left hand = trusted capture from jump. Right hand = build/act.
        Irony: God paints with it — meaning assigned before you see it; obvious after left hand held long enough.
        """
    }

    // MARK: - Private

    private func scoreText(
        _ text: String,
        speaker: NoteSpeaker,
        site: String,
        actions: [String],
        voiceConfidence: Double,
        rememberBoost: Bool,
        categoryBoost: Bool = false
    ) -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return 0 }

        var score = 0.35
        let lower = trimmed.lowercased()
        let currentSite = SiteContext.shared.currentSite.lowercased()

        if rememberBoost { score += 0.28 }
        if categoryBoost { score += 0.12 }
        if site.lowercased() == currentSite || site.lowercased() != "general" { score += 0.14 }
        if !actions.isEmpty { score += min(0.22, Double(actions.count) * 0.07) }
        if speaker == .jim { score += 0.1 }
        if speaker == .other && trimmed.count > 12 { score += 0.12 }
        if voiceConfidence > 0.7 { score += 0.08 }

        let noise = ["test", "asdf", "hello world", "lorem", "undefined", "null"]
        if noise.contains(where: { lower == $0 }) { score = 0.05 }
        if trimmed.count < 4 && !rememberBoost { score *= 0.5 }

        let k = CouplingLicense.shared.K
        let kScale = 0.65 + (min(k, CouplingLicense.kPeak) / CouplingLicense.kPeak) * 0.35
        return min(1.0, max(0, score * kScale))
    }

    private func buildCard(
        role: String,
        site: String,
        intention: String,
        score: Double,
        voiceConfidence: Double,
        actions: [String],
        leftHand: Bool
    ) -> CharacterCard {
        let verdict: JudgmentVerdict
        if score < Self.coupleThreshold {
            verdict = .reject
        } else if score < Self.decayThreshold {
            verdict = .decay
        } else {
            verdict = .couple
        }

        var irony = ""
        if verdict == .couple && role == "other" && !actions.isEmpty {
            irony = "Irony lane — assignment now; verbatim obvious after left hand held longer."
        } else if verdict == .decay {
            irony = "Weak coupling — may dissolve unless Jim throws it up again."
        }

        return CharacterCard(
            role: role,
            site: site,
            intention: intention,
            couplingScore: round(score * 1000) / 1000,
            voiceConfidence: voiceConfidence,
            actionTags: actions,
            leftHand: leftHand,
            verdict: verdict,
            ironyNote: irony
        )
    }
}

private extension ThrowTrust {
    static func detectIntention(from utterance: String, site: String) -> ThrowIntention {
        parse(utterance, site: site).intention
    }
}