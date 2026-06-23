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
    var complexion: String = "fair, thin — bruises stay visible longer"
    var bloodType: String = "" // ABO/Rh — confirm when typed; not on BH CBC pages
    var age: Int = 38
    var sex: String = "male"
    var location: String = "Columbus, NJ (farms)"
    var lastLabDate: String = "2026-06-15"

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
        storageURL = dir.appendingPathComponent("jim_health_profile.enc")
        SecureStorage.migratePlaintext(at: storageURL)
        load()
    }

    // MARK: - MC1R + Anna sync (from Jim's research — retuner not breaker)

    /// BH Patient Summary pages 6–7 — drawn 06/15/2026 ~04:00 EDT (Jim photos IMG_0107/0108).
    static let june2026LabPanel = """
    LABS 2026-06-15 (BH Patient Summary, James McCandless):
    CBC: WBC 5.0, RBC 5.53, Hgb 15.7, Hct 46.2%, MCV 84, MCH 28.4, MCHC 34.0, Plt 214, RDW 13.1%
    Diff: Neut 42% (2.1), Lymph 39% (1.9), Mono 9% (0.4), Eos 8% (0.1), Baso 2% (0.0)
    Chemistry: Glucose 88, Na 140, K 4.5, Cl 100, CO2 24, BUN 12, Creat 0.76, eGFR 107, Ca 10.0
    LFTs: AST 17, ALT 13, Alk Phos 103, T Bili 0.5, Albumin 4.7, TP 7.1
    Hgb A1c 5.4%. POC cap glucose 109 (flagged).
    Meds noted in chart: trazodone, olanzapine (oral). ADL index 40 — all independent.
    Platelets 214 + fair thin complexion → venipuncture bruise at day 4–5 is substrate-normal.
    """

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

    func updateBloodType(_ type: String) {
        bloodType = type.trimmingCharacters(in: .whitespacesAndNewlines)
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
        Phenotype: \(hairColor) hair, \(eyeColor) eyes, \(complexion). MC1R-relevant: \(mc1rPhenotypeLikely ? "yes (phenotype)" : "unknown").
        Blood type: \(bloodType.isEmpty ? "not yet on file — add ABO/Rh when known" : bloodType). Last lab panel: \(lastLabDate).

        \(Self.mc1rAnnaImplications)

        \(Self.june2026LabPanel)
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
        let complexion: String?
        let bloodType: String?
        let age: Int
        let sex: String
        let location: String
        let lastLabDate: String?
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
            complexion: complexion,
            bloodType: bloodType,
            age: age,
            sex: sex,
            location: location,
            lastLabDate: lastLabDate,
            mc1rPhenotypeLikely: mc1rPhenotypeLikely,
            mc1rGenotypeNotes: mc1rGenotypeNotes,
            healthRecordsText: healthRecordsText,
            lastRecordsImport: lastRecordsImport,
            syncedSummary: syncedSummary
        )
        guard let data = try? JSONEncoder().encode(storage) else { return }
        SecureStorage.write(data, to: storageURL)
    }

    private func load() {
        guard let data = SecureStorage.read(from: storageURL),
              let s = try? JSONDecoder().decode(Storage.self, from: data) else { return }
        hairColor = s.hairColor
        eyeColor = s.eyeColor
        complexion = s.complexion ?? complexion
        bloodType = s.bloodType ?? bloodType
        age = s.age
        sex = s.sex
        location = s.location
        lastLabDate = s.lastLabDate ?? lastLabDate
        mc1rPhenotypeLikely = s.mc1rPhenotypeLikely
        mc1rGenotypeNotes = s.mc1rGenotypeNotes
        healthRecordsText = s.healthRecordsText
        lastRecordsImport = s.lastRecordsImport
        syncedSummary = s.syncedSummary
    }
}