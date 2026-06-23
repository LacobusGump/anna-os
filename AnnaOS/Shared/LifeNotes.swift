import Foundation

/// Life Notes — trusted layer from jump. Verbatim capture before anyone asks.
/// Not pull-then-store: Anna already holds the receipt. Jim throws up more; query reads what's trusted.
/// Not Life Memory (facts on remember). This is who said what, when, word for word.
enum LifeNoteKind: String, Codable {
    case conversation
    case call
    case quoted
    case ambient
}

struct LifeNoteEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var verbatim: String
    var speaker: NoteSpeaker
    var attributedTo: String
    var actions: [String]
    var site: String
    var kind: LifeNoteKind
    var contextLabel: String
    var voiceConfidence: Double
    var card: CharacterCard?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        verbatim: String,
        speaker: NoteSpeaker,
        attributedTo: String = "",
        actions: [String] = [],
        site: String = "general",
        kind: LifeNoteKind = .conversation,
        contextLabel: String = "",
        voiceConfidence: Double = 0,
        card: CharacterCard? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.verbatim = verbatim
        self.speaker = speaker
        self.attributedTo = attributedTo
        self.actions = actions
        self.site = site.lowercased()
        self.kind = kind
        self.contextLabel = contextLabel
        self.voiceConfidence = voiceConfidence
        self.card = card
        self.createdAt = createdAt
    }
}

final class LifeNotes: ObservableObject {
    static let shared = LifeNotes()

    /// Jim trust — big-brother verbatim capture ON by default for Person #1.
    static var trustCaptureEnabled: Bool { true }

    @Published private(set) var entries: [LifeNoteEntry] = []

    private let storageURL: URL
    private let maxEntries = 2000

    static let claudeInstructions = """
    LIFE NOTES (left hand — trusted layer from jump):
    Verbatim capture with character card judgment. Rejected notes don't couple — never quote them.
    When he asks what was actually said: quote VERBATIM from coupled notes only. No paraphrase.
    Throw hands more up; query reads what's already trusted. Irony: obvious after left held long enough.
    """

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("anna_life_notes.enc")
        SecureStorage.migratePlaintext(at: storageURL)
        load()
    }

    // MARK: - Query detection

    static func hasTranscriptQuery(_ utterance: String) -> Bool {
        let q = utterance.lowercased()
        let triggers = [
            "what did they say", "what did he say", "what did she say",
            "actually say", "actually said", "verbatim", "transcript",
            "when they told me", "when he told me", "when she told me",
            "say when they", "say when he", "say when she",
        ]
        if triggers.contains(where: { q.contains($0) }) { return true }
        return q.contains("transcript") || (q.contains("say") && q.contains("build"))
            || (q.contains("say") && q.contains("call"))
    }

    static func hasNoteCaptureIntent(_ utterance: String) -> Bool {
        let q = utterance.lowercased()
        return q.contains("they said") || q.contains("he said") || q.contains("she said")
            || q.contains("told me to") || q.contains("told me")
    }

    // MARK: - Record

    func record(
        verbatim: String,
        speaker: NoteSpeaker,
        attributedTo: String = "",
        site: String = "",
        kind: LifeNoteKind = .conversation,
        contextLabel: String = "",
        voiceConfidence: Double = 0
    ) {
        guard trustCaptureEnabled else { return }
        let text = verbatim.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2 else { return }

        let effectiveSite = site.isEmpty ? SiteContext.shared.currentSite : site
        let actions = Self.extractActions(from: text)
        let card = CouplingJudge.shared.judgeNote(
            verbatim: text,
            speaker: speaker,
            site: effectiveSite,
            voiceConfidence: voiceConfidence
        )
        guard card.verdict != .reject else { return }

        entries.append(LifeNoteEntry(
            verbatim: text,
            speaker: speaker,
            attributedTo: attributedTo,
            actions: actions,
            site: effectiveSite,
            kind: kind,
            contextLabel: contextLabel,
            voiceConfidence: voiceConfidence,
            card: card
        ))

        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        save()
    }

    func recordJimUtterance(_ text: String, contextLabel: String = "", voiceConfidence: Double = 1.0) {
        record(verbatim: text, speaker: .jim, site: SiteContext.shared.currentSite,
               kind: .conversation, contextLabel: contextLabel, voiceConfidence: voiceConfidence)
    }

    func recordAnnaReply(_ text: String, replyingTo: String = "") {
        record(verbatim: text, speaker: .anna, site: SiteContext.shared.currentSite,
               kind: .conversation, contextLabel: replyingTo.isEmpty ? "reply" : "reply:\(replyingTo.prefix(40))")
    }

    func recordCallNotes(_ notes: String, contact: String = "") {
        guard trustCaptureEnabled, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        record(verbatim: notes, speaker: .other, attributedTo: contact,
               site: CallContext.shared.siteHint.isEmpty ? SiteContext.shared.currentSite : CallContext.shared.siteHint,
               kind: .call, contextLabel: "call_log")
    }

    /// Jim reports what someone said — store as quoted other speech.
    func ingestQuotedSpeech(from jimUtterance: String) {
        let patterns: [(String, Int)] = [
            (#"(?i)(?:they|he|she)\s+said[,:]?\s*["']?(.+?)["']?$"#, 1),
            (#"(?i)told me to\s+(.+)$"#, 1),
            (#"(?i)told me[,:]?\s*["']?(.+?)["']?$"#, 1),
        ]
        for (pattern, group) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: jimUtterance, range: NSRange(jimUtterance.startIndex..., in: jimUtterance)),
                  match.numberOfRanges > group,
                  let range = Range(match.range(at: group), in: jimUtterance) else { continue }
            let quote = String(jimUtterance[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard quote.count > 3 else { continue }
            let who = inferSpeakerName(from: jimUtterance) ?? CallContext.shared.contactName
            record(verbatim: quote, speaker: .other, attributedTo: who,
                   site: SiteContext.shared.currentSite, kind: .quoted, contextLabel: "jim_reported")
            return
        }
    }

    // MARK: - Search

    func search(query: String, speaker: NoteSpeaker? = nil, site: String = "", limit: Int = 8) -> [LifeNoteEntry] {
        let tokens = tokenize(query)
        let siteFilter = site.lowercased()

        let scored = entries.map { entry -> (LifeNoteEntry, Int) in
            if entry.card?.verdict == .reject { return (entry, 0) }
            if let speaker, entry.speaker != speaker { return (entry, 0) }
            var score = 0
            let hay = [
                entry.verbatim, entry.attributedTo, entry.contextLabel,
                entry.site, entry.kind.rawValue,
            ].joined(separator: " ") + " " + entry.actions.joined(separator: " ")

            for token in tokens {
                if hay.localizedCaseInsensitiveContains(token) { score += 2 }
                if entry.actions.contains(where: { $0.contains(token) }) { score += 4 }
                if entry.verbatim.localizedCaseInsensitiveContains(token) { score += 3 }
            }
            if tokens.contains(where: { ["they", "he", "she", "other"].contains($0) }) && entry.speaker == .other {
                score += 5
            }
            if !siteFilter.isEmpty, entry.site == siteFilter { score += 3 }
            if let k = entry.card?.couplingScore, k >= CouplingJudge.decayThreshold { score += 2 }
            return (entry, score)
        }
        .filter { $0.1 > 0 }
        .sorted { $0.1 > $1.1 }
        .prefix(limit)
        .map(\.0)

        return Array(scored)
    }

    func contextBlock(for query: String, site: String = "") -> String {
        guard trustCaptureEnabled else { return "LIFE NOTES: trust capture off." }
        let effectiveSite = site.isEmpty ? SiteContext.shared.currentSite : site
        let wantOther = query.lowercased().contains("they") || query.lowercased().contains("he ")
            || query.lowercased().contains("she ")
        let speaker: NoteSpeaker? = wantOther ? .other : nil
        let matches = search(query: query, speaker: speaker, site: effectiveSite, limit: 10)

        guard !matches.isEmpty else {
            return """
            LIFE NOTES: \(entries.count) verbatim captures. None matched "\(query.isEmpty ? "recent" : query)" — do not invent dialogue.
            \(VoiceIdentity.shared.contextBlock())
            """
        }

        let lines = matches.map { e in
            let who = e.speaker == .other && !e.attributedTo.isEmpty ? e.attributedTo : e.speaker.rawValue
            let when = e.createdAt.formatted(date: .abbreviated, time: .shortened)
            let acts = e.actions.isEmpty ? "" : " [\(e.actions.joined(separator: ","))]"
            let k = e.card.map { String(format: " K=%.2f", $0.couplingScore) } ?? ""
            return "- \(when) @\(e.site) \(who)\(acts)\(k): \"\(e.verbatim)\""
        }.joined(separator: "\n")

        return """
        LIFE NOTES — VERBATIM (Jim trust capture, \(entries.count) total):
        Quote these exactly when asked what was said. Do not paraphrase.

        \(lines)

        \(VoiceIdentity.shared.contextBlock())
        """
    }

    private static let actionVerbs = ["build", "call", "do", "need", "order", "bring", "fix", "send", "email", "text"]

    static func extractActions(from text: String) -> [String] {
        let lower = text.lowercased()
        return actionVerbs.filter { lower.contains($0) }
    }

    func jsonSnapshot() -> String {
        let recent = entries.suffix(40)
        guard let data = try? JSONEncoder().encode(Array(recent)),
              let text = String(data: data, encoding: .utf8) else { return "[]" }
        return text
    }

    func applySnapshot(_ json: String) {
        guard let data = json.data(using: .utf8),
              let incoming = try? JSONDecoder().decode([LifeNoteEntry].self, from: data) else { return }
        for note in incoming where !entries.contains(where: { $0.id == note.id }) {
            entries.append(note)
        }
        entries.sort { $0.createdAt > $1.createdAt }
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        save()
    }

    var count: Int { entries.count }

    // MARK: - Private

    private func inferSpeakerName(from utterance: String) -> String? {
        let lower = utterance.lowercased()
        if lower.contains("johnson") { return "Johnson" }
        if let regex = try? NSRegularExpression(pattern: #"(?i)([A-Z][a-z]+)\s+said"#),
           let match = regex.firstMatch(in: utterance, range: NSRange(utterance.startIndex..., in: utterance)),
           let range = Range(match.range(at: 1), in: utterance) {
            return String(utterance[range])
        }
        return nil
    }

    private func tokenize(_ query: String) -> [String] {
        query.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        SecureStorage.write(data, to: storageURL)
    }

    private func load() {
        guard let data = SecureStorage.read(from: storageURL),
              let decoded = try? JSONDecoder().decode([LifeNoteEntry].self, from: data) else { return }
        entries = decoded
    }
}