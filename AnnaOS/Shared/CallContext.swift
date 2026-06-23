import Foundation

/// Last phone call context — disambiguates which deck, which job, who just called.
/// v1: Jim pastes or says "remember" after a call. Future: CallKit + Anna as provider number.
final class CallContext: ObservableObject {
    static let shared = CallContext()

    @Published var lastCallNotes: String = ""
    @Published private(set) var contactName: String = ""
    @Published private(set) var topic: String = ""
    @Published private(set) var siteHint: String = ""
    @Published private(set) var endedAt: Date?

    private let storageURL: URL

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("anna_call_context.json")
        load()
    }

    func updateNotes(_ notes: String) {
        lastCallNotes = notes
        parseNotes(notes)
        save()
    }

    func contextBlock() -> String {
        guard !lastCallNotes.isEmpty else {
            return """
            CALL CONTEXT: none logged. If Jim just hung up, his "remember" may refer to that call.
            Future: Anna listens on her own number (provider edge) — Jim Person #1, full consent.
            """
        }

        let when = endedAt.map { "ended \($0.formatted(date: .omitted, time: .shortened))" } ?? "time unknown"
        return """
        CALL CONTEXT (last call — use to disambiguate work vs home lists):
        \(lastCallNotes)
        Parsed: contact=\(contactName.isEmpty ? "?" : contactName), topic=\(topic.isEmpty ? "?" : topic), site_hint=\(siteHint.isEmpty ? "?" : siteHint), \(when)
        If Jim says "remember" right after a call, bind memories to site_hint or current geo site.
        """
    }

    func markCallEnded(contact: String = "", topic: String = "", siteHint: String = "") {
        contactName = contact
        self.topic = topic
        self.siteHint = siteHint
        endedAt = Date()
        save()
    }

    private func parseNotes(_ notes: String) {
        let lower = notes.lowercased()
        if lower.contains("deck") || lower.contains("2x6") || lower.contains("lumber") {
            topic = topic.isEmpty ? "deck/materials" : topic
        }
        if lower.contains("johnson") { contactName = contactName.isEmpty ? "Johnson" : contactName }
        if lower.contains("work") || lower.contains("client") || lower.contains("job") {
            siteHint = siteHint.isEmpty ? "work" : siteHint
        }
        if lower.contains("home") || lower.contains("house") {
            siteHint = siteHint.isEmpty ? "home" : siteHint
        }
        endedAt = Date()
    }

    private struct Stored: Codable {
        var lastCallNotes: String
        var contactName: String
        var topic: String
        var siteHint: String
        var endedAt: Date?
    }

    private func save() {
        let stored = Stored(
            lastCallNotes: lastCallNotes,
            contactName: contactName,
            topic: topic,
            siteHint: siteHint,
            endedAt: endedAt
        )
        guard let data = try? JSONEncoder().encode(stored) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let stored = try? JSONDecoder().decode(Stored.self, from: data) else { return }
        lastCallNotes = stored.lastCallNotes
        contactName = stored.contactName
        topic = stored.topic
        siteHint = stored.siteHint
        endedAt = stored.endedAt
    }
}