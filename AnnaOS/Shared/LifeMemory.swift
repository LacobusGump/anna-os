import Foundation

/// Life Memory — THE KEY. Profile is seed; memories are Jim's life learned in place.
/// "Hey Anna, I'm making an omelet" → eggs_count: 5, grab mayo, offer help or music.
enum MemoryCategory: String, Codable, CaseIterable {
    case kitchen
    case inventory
    case health
    case music
    case people
    case build
    case driving
    case preference
    case episodic
}

struct LifeMemoryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var category: MemoryCategory
    var key: String
    var value: String
    var note: String
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date
    var source: String

    init(
        id: UUID = UUID(),
        category: MemoryCategory,
        key: String,
        value: String,
        note: String = "",
        tags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        source: String = "jim"
    ) {
        self.id = id
        self.category = category
        self.key = key
        self.value = value
        self.note = note
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.source = source
    }
}

final class LifeMemory: ObservableObject {
    static let shared = LifeMemory()

    @Published private(set) var entries: [LifeMemoryEntry] = []

    private let storageURL: URL
    private let memoryTagPattern = #"<anna_memory>(.*?)</anna_memory>"#

    static let claudeInstructions = """
    LIFE MEMORY (THE KEY — use these, do not guess over them):
    - Memories below are Jim's actual life. Profile is seed; memories are what you learned in place.
    - When he asks about something (omelet, deck, Route 22), USE matching memories first.
    - Example tone: "Last time you had 5 eggs left — grab 3, mayo, can of veggies. Help or just music?"
    - When Jim states a new fact to remember, append hidden tags (one per fact):
    <anna_memory>{"category":"kitchen","key":"eggs_count","value":"5","note":"after omelet","tags":["eggs","fridge"]}</anna_memory>
    - Stable keys: eggs_count, omelet_ingredients_usual, shan_route_music, deck_boards_owned, etc.
    - Upsert keys — same key updates value. Partner mode: offer help OR music, not both unless asked.
    """

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("anna_life_memory.json")
        load()
    }

    // MARK: - CRUD

    func upsert(
        category: MemoryCategory,
        key: String,
        value: String,
        note: String = "",
        tags: [String] = [],
        source: String = "jim"
    ) {
        let normalizedKey = key.lowercased().replacingOccurrences(of: " ", with: "_")
        if let idx = entries.firstIndex(where: { $0.category == category && $0.key == normalizedKey }) {
            entries[idx].value = value
            entries[idx].note = note.isEmpty ? entries[idx].note : note
            if !tags.isEmpty { entries[idx].tags = tags }
            entries[idx].updatedAt = Date()
            entries[idx].source = source
        } else {
            entries.append(LifeMemoryEntry(
                category: category,
                key: normalizedKey,
                value: value,
                note: note,
                tags: tags,
                source: source
            ))
        }
        save()
    }

    func search(query: String, limit: Int = 12) -> [LifeMemoryEntry] {
        let tokens = tokenize(query)
        guard !tokens.isEmpty else { return Array(entries.suffix(limit)) }

        let scored = entries.map { entry -> (LifeMemoryEntry, Int) in
            var score = 0
            let haystack = [
                entry.category.rawValue,
                entry.key,
                entry.value,
                entry.note
            ].joined(separator: " ") + " " + entry.tags.joined(separator: " ")

            for token in tokens {
                if haystack.localizedCaseInsensitiveContains(token) { score += 2 }
                if entry.key.localizedCaseInsensitiveContains(token) { score += 3 }
                if entry.tags.contains(where: { $0.localizedCaseInsensitiveContains(token) }) { score += 2 }
            }
            return (entry, score)
        }
        .filter { $0.1 > 0 }
        .sorted { $0.1 > $1.1 }
        .prefix(limit)
        .map(\.0)

        return Array(scored)
    }

    func contextBlock(for query: String) -> String {
        let matches = search(query: query)
        guard !matches.isEmpty else {
            return """
            LIFE MEMORIES: \(entries.count) stored. None matched "\(query.isEmpty ? "wake" : query)" yet — learn from this conversation.
            """
        }

        let lines = matches.map { e in
            "- [\(e.category.rawValue)] \(e.key) = \(e.value)\(e.note.isEmpty ? "" : " (\(e.note))")"
        }.joined(separator: "\n")

        return """
        LIFE MEMORIES (\(entries.count) total, \(matches.count) relevant):
        \(lines)
        """
    }

    // MARK: - Claude ingest

    func ingestFromResponse(_ response: String) -> String {
        var cleaned = response
        let regex = try? NSRegularExpression(pattern: memoryTagPattern, options: [.dotMatchesLineSeparators])

        guard let regex else { return response }
        let ns = response as NSString
        let matches = regex.matches(in: response, range: NSRange(location: 0, length: ns.length))

        for match in matches.reversed() {
            guard match.numberOfRanges > 1 else { continue }
            let jsonRange = match.range(at: 1)
            let jsonStr = ns.substring(with: jsonRange)
            if let entry = decodeMemoryJSON(jsonStr) {
                upsert(
                    category: entry.category,
                    key: entry.key,
                    value: entry.value,
                    note: entry.note,
                    tags: entry.tags,
                    source: "conversation"
                )
            }
            cleaned = (cleaned as NSString).replacingCharacters(in: match.range, with: "")
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func decodeMemoryJSON(_ json: String) -> LifeMemoryEntry? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let catStr = obj["category"] as? String,
              let category = MemoryCategory(rawValue: catStr),
              let key = obj["key"] as? String,
              let value = obj["value"] as? String else { return nil }

        let note = obj["note"] as? String ?? ""
        let tags = obj["tags"] as? [String] ?? []
        return LifeMemoryEntry(category: category, key: key, value: value, note: note, tags: tags, source: "conversation")
    }

    // MARK: - Quick add (iPhone paste: kitchen.eggs_count=5)

    func ingestQuickLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let parts = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return false }

        let left = parts[0].trimmingCharacters(in: .whitespaces)
        let value = parts[1].trimmingCharacters(in: .whitespaces)
        let segments = left.split(separator: ".", maxSplits: 1).map(String.init)
        guard segments.count == 2,
              let category = MemoryCategory(rawValue: segments[0].lowercased()) else { return false }

        upsert(category: category, key: segments[1], value: value, source: "jim_paste")
        return true
    }

    // MARK: - Sync

    func jsonSnapshot() -> String {
        guard let data = try? JSONEncoder().encode(entries),
              let str = String(data: data, encoding: .utf8) else { return "[]" }
        return str
    }

    func applySnapshot(_ json: String) {
        guard let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([LifeMemoryEntry].self, from: data) else { return }
        entries = decoded
        save()
    }

    var count: Int { entries.count }

    // MARK: - Private

    private func tokenize(_ query: String) -> [String] {
        query.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([LifeMemoryEntry].self, from: data) else { return }
        entries = decoded
    }
}