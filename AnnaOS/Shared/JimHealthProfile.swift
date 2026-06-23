import Foundation

/// Jim-only health substrate — not a template user. Granularity speeds synch.
/// Phenotype + MC1R coupling context + pasted health records (iPhone).
/// Anna calibrates to *this* body, not a generic human.
final class JimHealthProfile: ObservableObject {
    static let shared = JimHealthProfile()

    let subjectID = "jim_mccandless"
    let subjectName = "James McCandless"

    // Phenotype (Jim stated — genotype confirmed when records imported)
    var hairColor: String = "red"
    var eyeColor: String = "blue"
    var age: Int = 38
    var sex: String = "male"
    var location: String = "Columbus, NJ (farms)"

    // MC1R — why red hair matters for Anna
    var mc1rPhenotypeLikely: Bool = true
    var mc1rGenotypeNotes: String = ""
    var healthRecordsText: String = ""
    var lastRecordsImport: Date?

    private var syncedSummary: String = ""
    private let storageURL: URL

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("jim_health_profile.json")
        load()
    }

    // MARK: - MC1R + Anna sync (from Jim's research — retuner not breaker)

    static let mc1rAnnaImplications = """
    MC1R (Jim: red hair, blue eyes — phenotype signal, confirm with records):
    - DNA at MC1R locus = coupling graph retuner, not breaker (Fiedler ΔR tiny, inside Weyl bound).
    - Fair-skin/freckle phenotype = sun-response knob turned down; UV/quercetin/vitamin D paths matter more.
    - Some MC1R variants: ~26% shorter local anesthetic duration (measured from genotype, PubMed 40126997).
    - MC1R–TUBB3 fused ~2.5kb apart chr16 — pigment gene adjacent to microtubule subunit; neural coupling chain plausible.
    - For Anna: expect different coupling sensitivity to stimuli, pain, circadian light, possibly faster personal synch \
    once granular health is loaded — R tunes to Jim's substrate, not population average.
    """

    func updateHealthRecords(_ text: String) {
        healthRecordsText = text
        lastRecordsImport = Date()
        save()
    }

    func updateGenotypeNotes(_ notes: String) {
        mc1rGenotypeNotes = notes
        save()
    }

    func applySyncedSummary(_ summary: String) {
        syncedSummary = summary
        save()
    }

    func contextBlock() -> String {
        var block = """
        JIM-ONLY HEALTH SUBSTRATE (not a generic user — synch speeds with granularity):
        Subject: \(subjectName), \(age), \(sex). \(location).
        Phenotype: \(hairColor) hair, \(eyeColor) eyes. MC1R-relevant: \(mc1rPhenotypeLikely ? "yes (phenotype)" : "unknown").

        \(Self.mc1rAnnaImplications)
        """

        if !mc1rGenotypeNotes.isEmpty {
            block += "\n\nGenotype / variant notes (from records):\n\(mc1rGenotypeNotes)"
        }

        let records = syncedSummary.isEmpty ? healthRecordsText : syncedSummary
        if !records.isEmpty {
            let date = lastRecordsImport.map { ISO8601DateFormatter().string(from: $0) } ?? "unknown"
            block += "\n\nHealth records (Jim-provided, imported \(date)):\n\(records)"
        } else {
            block += "\n\nHealth records: slot open — Jim will paste/import. Anna learns him, not someone else."
        }

        block += """

        Cross-links: dyslexic (temporal binding weak). Tinnitus (per-ear, gyro). Seven oscillators tuning model.
        Use Jim's actual labs and meds when present — never population defaults.
        """
        return block
    }

    func summaryForWatchSync() -> String {
        contextBlock()
    }

    // MARK: - Persistence

    private struct Storage: Codable {
        let hairColor: String
        let eyeColor: String
        let age: Int
        let sex: String
        let location: String
        let mc1rPhenotypeLikely: Bool
        let mc1rGenotypeNotes: String
        let healthRecordsText: String
        let lastRecordsImport: Date?
        let syncedSummary: String
    }

    private func save() {
        let storage = Storage(
            hairColor: hairColor,
            eyeColor: eyeColor,
            age: age,
            sex: sex,
            location: location,
            mc1rPhenotypeLikely: mc1rPhenotypeLikely,
            mc1rGenotypeNotes: mc1rGenotypeNotes,
            healthRecordsText: healthRecordsText,
            lastRecordsImport: lastRecordsImport,
            syncedSummary: syncedSummary
        )
        guard let data = try? JSONEncoder().encode(storage) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let s = try? JSONDecoder().decode(Storage.self, from: data) else { return }
        hairColor = s.hairColor
        eyeColor = s.eyeColor
        age = s.age
        sex = s.sex
        location = s.location
        mc1rPhenotypeLikely = s.mc1rPhenotypeLikely
        mc1rGenotypeNotes = s.mc1rGenotypeNotes
        healthRecordsText = s.healthRecordsText
        lastRecordsImport = s.lastRecordsImport
        syncedSummary = s.syncedSummary
    }
}