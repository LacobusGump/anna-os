import Foundation

/// Life Memory — THE KEY. Profile is seed; memories are Jim's life learned in place.
/// Air-gapped by consent: Jim says WHAT to remember. Site + call context disambiguate work vs home.
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
    case work
}

struct LifeMemoryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var category: MemoryCategory
    var key: String
    var value: String
    var note: String
    var tags: [String]
    var site: String
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
        site: String = "general",
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
        self.site = site.lowercased()
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.source = source
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        category = try c.decode(MemoryCategory.self, forKey: .category)
        key = try c.decode(String.self, forKey: .key)
        value = try c.decode(String.self, forKey: .value)
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        site = (try c.decodeIfPresent(String.self, forKey: .site) ?? "general").lowercased()
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        source = try c.decodeIfPresent(String.self, forKey: .source) ?? "jim"
    }
}

final class LifeMemory: ObservableObject {
    static let shared = LifeMemory()

    @Published private(set) var entries: [LifeMemoryEntry] = []

    private let storageURL: URL
    private let memoryTagPattern = #"<anna_memory>(.*?)</anna_memory>"#

    static let claudeInstructions = """
    LIFE MEMORY (THE KEY — use these, do not guess over them):

    CONSENT (air-gap):
    - Jim is Person #1 — willing to give Anna everything eventually, but storage is gated.
    - ONLY persist new facts when Jim said "remember" / "don't forget" / "store this" in this turn,
      OR when he used quick-add on iPhone, OR when hidden tags are emitted during an active remember command.
    - Do NOT silently store casual chat. Retrieve freely; write only on consent.

    INVENTORY (anything left):
    - Track quantities Jim tells you to remember: eggs, paint gallons, screws, 2x6s, mayo, anything.
    - Keys like eggs_count, paint_gallon_left, screws_3inch_left, lumber_2x6_count.
    - Category: inventory for counts; kitchen for food; build for materials and how-to.

    SITE SCOPE (work deck ≠ home deck):
    - Memories carry a site: home, farm, work, general, or client name.
    - Current site + last call context disambiguate which list Jim means.
    - "Remember twelve 2x6s" at work → build@work.deck_materials_list, not home.
    - Deck HOW-TO (face screw, gap, railing style) is build@home.deck_style or build@work.deck_style.

    REMEMBER COMMAND:
    - "Hey Anna, remember …" → confirm what you stored, one line, partner tone.
    - Append hidden tags (one per fact) ONLY during remember commands:
    <anna_memory>{"category":"build","key":"deck_materials_list","value":"12x 2x6x12, deck screws box","site":"work","note":"Johnson job","tags":["deck","lumber"]}</anna_memory>
    <anna_memory>{"category":"inventory","key":"eggs_count","value":"5","site":"home","tags":["eggs","fridge"]}</anna_memory>

    RETRIEVE EXAMPLES:
    - Omelet: "Last time you had 5 eggs left — grab 3, mayo, can of veggies. Help or just music?"
    - Deck: "Home deck — face screw, 3/16 gap. Work Johnson job — you remembered 12 2x6s last call."

    Partner mode: offer help OR music, not both unless asked.
    """

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("anna_life_memory.enc")
        SecureStorage.migratePlaintext(at: storageURL)
        load()
    }

    // MARK: - Remember intent

    static func hasRememberIntent(_ utterance: String) -> Bool {
        let lower = utterance.lowercased()
        let triggers = ["remember", "don't forget", "dont forget", "store this", "write this down", "keep track"]
        return triggers.contains { lower.contains($0) }
    }

    // MARK: - CRUD

    func upsert(
        category: MemoryCategory,
        key: String,
        value: String,
        note: String = "",
        tags: [String] = [],
        site: String = "general",
        source: String = "jim"
    ) {
        let normalizedKey = key.lowercased().replacingOccurrences(of: " ", with: "_")
        let normalizedSite = site.lowercased()
        if let idx = entries.firstIndex(where: {
            $0.category == category && $0.key == normalizedKey && $0.site == normalizedSite
        }) {
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
                site: normalizedSite,
                source: source
            ))
        }
        save()
    }

    func search(query: String, site: String = "", limit: Int = 12) -> [LifeMemoryEntry] {
        let tokens = tokenize(query)
        let siteBoost = site.lowercased()

        let scored = entries.map { entry -> (LifeMemoryEntry, Int) in
            var score = 0
            let haystack = [
                entry.category.rawValue,
                entry.key,
                entry.value,
                entry.note,
                entry.site
            ].joined(separator: " ") + " " + entry.tags.joined(separator: " ")

            if !tokens.isEmpty {
                for token in tokens {
                    if haystack.localizedCaseInsensitiveContains(token) { score += 2 }
                    if entry.key.localizedCaseInsensitiveContains(token) { score += 3 }
                    if entry.tags.contains(where: { $0.localizedCaseInsensitiveContains(token) }) { score += 2 }
                }
            } else {
                score = 1
            }

            if !siteBoost.isEmpty && siteBoost != "general" {
                if entry.site == siteBoost { score += 5 }
                if entry.site == "general" { score += 1 }
            }

            return (entry, score)
        }
        .filter { tokens.isEmpty ? true : $0.1 > 0 }
        .sorted { $0.1 > $1.1 }
        .prefix(limit)
        .map(\.0)

        return Array(scored)
    }

    func contextBlock(for query: String, site: String = "") -> String {
        let effectiveSite = site.isEmpty ? SiteContext.shared.currentSite : site
        let matches = search(query: query, site: effectiveSite)
        guard !matches.isEmpty else {
            return """
            LIFE MEMORIES: \(entries.count) stored. None matched "\(query.isEmpty ? "wake" : query)" at site \(effectiveSite) — learn only if Jim said remember.
            """
        }

        let lines = matches.map { e in
            let siteTag = e.site == "general" ? "" : "@\(e.site)"
            return "- [\(e.category.rawValue)\(siteTag)] \(e.key) = \(e.value)\(e.note.isEmpty ? "" : " (\(e.note))")"
        }.joined(separator: "\n")

        return """
        LIFE MEMORIES (\(entries.count) total, \(matches.count) relevant, site=\(effectiveSite)):
        \(lines)
        """
    }

    func inventoryBlock(site: String = "") -> String {
        let effectiveSite = site.isEmpty ? SiteContext.shared.currentSite : site
        let items = entries.filter {
            $0.category == .inventory || $0.key.hasSuffix("_count") || $0.key.hasSuffix("_left")
        }
        let filtered = items.filter { $0.site == effectiveSite || $0.site == "general" }
        guard !filtered.isEmpty else { return "INVENTORY@\(effectiveSite): none logged yet." }
        let lines = filtered.map { "- \($0.key) = \($0.value) (@\($0.site))" }.joined(separator: "\n")
        return "INVENTORY@\(effectiveSite):\n\(lines)"
    }

    // MARK: - Claude ingest (consent-gated)

    func ingestFromResponse(_ response: String, allowStore: Bool) -> String {
        guard allowStore else { return stripTags(from: response) }
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
                    site: entry.site,
                    source: "conversation"
                )
            }
            cleaned = (cleaned as NSString).replacingCharacters(in: match.range, with: "")
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func stripTags(from response: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: memoryTagPattern, options: [.dotMatchesLineSeparators]) else {
            return response
        }
        let ns = response as NSString
        let range = NSRange(location: 0, length: ns.length)
        return regex.stringByReplacingMatches(in: response, range: range, withTemplate: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
        let site = obj["site"] as? String ?? SiteContext.shared.currentSite
        return LifeMemoryEntry(
            category: category,
            key: key,
            value: value,
            note: note,
            tags: tags,
            site: site,
            source: "conversation"
        )
    }

    // MARK: - Quick add
    // Formats:
    //   kitchen.eggs_count=5
    //   inventory@home.paint_gallon_left=2
    //   build@work.deck_materials_list=12x 2x6x12

    func ingestQuickLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let parts = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return false }

        let left = parts[0].trimmingCharacters(in: .whitespaces)
        let value = parts[1].trimmingCharacters(in: .whitespaces)

        var site = "general"
        var categoryKey = left

        if let atRange = left.range(of: "@") {
            let catPart = String(left[..<atRange.lowerBound])
            let siteAndKey = String(left[atRange.upperBound...])
            let siteKeyParts = siteAndKey.split(separator: ".", maxSplits: 1).map(String.init)
            guard siteKeyParts.count == 2 else { return false }
            site = siteKeyParts[0].lowercased()
            categoryKey = "\(catPart).\(siteKeyParts[1])"
        }

        let segments = categoryKey.split(separator: ".", maxSplits: 1).map(String.init)
        guard segments.count == 2,
              let category = MemoryCategory(rawValue: segments[0].lowercased()) else { return false }

        upsert(category: category, key: segments[1], value: value, site: site, source: "jim_paste")
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
        SecureStorage.write(data, to: storageURL)
    }

    private func load() {
        guard let data = SecureStorage.read(from: storageURL),
              let decoded = try? JSONDecoder().decode([LifeMemoryEntry].self, from: data) else { return }
        entries = decoded
    }
}