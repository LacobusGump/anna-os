import Foundation

/// Intentional Understanding — timing is intention data, not a missing dimension.
///
/// Reverse bar exam: the bar overloads you with questions and scores speed + accuracy together.
/// Jim's calibration overloads with *one* word — the time to tap yes/no is how fast his mind
/// arrives at a commit. Long pause ≠ idle. Rush ≠ careless. Gap between interactions = personal rhythm.
enum TimingKind: String, Codable {
    case calibrationTap
    case wakeWord
    case conversationEnd
    case promptAbandoned
}

enum TempoClass: String, Codable {
    case rush
    case deliberate
    case stall
    case unknown
}

struct TimingObservation: Codable, Identifiable {
    let id: UUID
    let kind: TimingKind
    let tempo: TempoClass
    let latencyMs: Int
    let gapSinceLastMs: Int
    let contextLabel: String
    let confirmed: Bool?
    let timestamp: Date
    let inference: String
}

struct PersonalTempo: Codable {
    var globalMedianTapMs: Double = 2800
    var perContextMedian: [String: Double] = [:]
    var sampleCount: Int = 0
}

final class IntentionalUnderstanding {
    private var observations: [TimingObservation] = []
    private var tempo = PersonalTempo()
    private var openPrompt: (label: String, shownAt: Date)?
    private var lastEventAt: Date?

    private let storageURL: URL
    private let maxObservations = 500

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("anna_intentional_understanding.json")
        load()
    }

    // MARK: - Events

    func promptPresented(label: String) {
        if let open = openPrompt, open.label != label {
            recordPromptAbandoned(label: open.label)
        }
        openPrompt = (label, Date())
    }

    @discardableResult
    func recordCalibrationTap(label: String, confirmed: Bool) -> TimingObservation {
        let now = Date()
        let latencyMs = openPrompt.map { Int(now.timeIntervalSince($0.shownAt) * 1000) } ?? 0
        let gapMs = gapSinceLast(from: now)
        let tempoClass = classify(latencyMs: Double(latencyMs), context: label)
        updateBaseline(latencyMs: Double(latencyMs), context: label)

        let obs = TimingObservation(
            id: UUID(),
            kind: .calibrationTap,
            tempo: tempoClass,
            latencyMs: latencyMs,
            gapSinceLastMs: gapMs,
            contextLabel: label,
            confirmed: confirmed,
            timestamp: now,
            inference: inferenceForTap(tempo: tempoClass, latencyMs: latencyMs, label: label, confirmed: confirmed)
        )
        append(obs)
        openPrompt = nil
        lastEventAt = now
        save()
        return obs
    }

    func recordWakeWord() {
        let now = Date()
        let gapMs = gapSinceLast(from: now)
        let obs = TimingObservation(
            id: UUID(),
            kind: .wakeWord,
            tempo: gapMs > 120_000 ? .stall : gapMs < 5_000 ? .rush : .deliberate,
            latencyMs: 0,
            gapSinceLastMs: gapMs,
            contextLabel: "hey_anna",
            confirmed: nil,
            timestamp: now,
            inference: gapMs > 120_000
                ? "Long silence before Hey Anna — likely intentional pause, not absence."
                : "Hey Anna after \(gapMs / 1000)s gap."
        )
        append(obs)
        lastEventAt = now
        save()
    }

    func recordConversationEnd() {
        let now = Date()
        let gapMs = gapSinceLast(from: now)
        let obs = TimingObservation(
            id: UUID(),
            kind: .conversationEnd,
            tempo: .deliberate,
            latencyMs: 0,
            gapSinceLastMs: gapMs,
            contextLabel: "conversation",
            confirmed: nil,
            timestamp: now,
            inference: "Conversation closed. Duration since wake: \(gapMs / 1000)s."
        )
        append(obs)
        lastEventAt = now
        save()
    }

    func recordPromptAbandoned(label: String) {
        guard let open = openPrompt, open.label == label else { return }
        let now = Date()
        let latencyMs = Int(now.timeIntervalSince(open.shownAt) * 1000)
        let obs = TimingObservation(
            id: UUID(),
            kind: .promptAbandoned,
            tempo: .stall,
            latencyMs: latencyMs,
            gapSinceLastMs: gapSinceLast(from: now),
            contextLabel: label,
            confirmed: nil,
            timestamp: now,
            inference: "No tap in \(latencyMs / 1000)s on \"\(label)\" — question may be too hard to say one thing, or moment shifted."
        )
        append(obs)
        openPrompt = nil
        lastEventAt = now
        save()
    }

    // MARK: - Analysis

    func classify(latencyMs: Double, context: String) -> TempoClass {
        guard latencyMs > 0 else { return .unknown }
        let baseline = tempo.perContextMedian[context] ?? tempo.globalMedianTapMs
        let ratio = latencyMs / max(baseline, 500)

        if latencyMs >= 12_000 { return .stall }
        if ratio < 0.55 { return .rush }
        if ratio > 1.75 || latencyMs >= 6_000 { return .stall }
        return .deliberate
    }

    func contextBlock() -> String {
        let recent = observations.suffix(5)
        guard !recent.isEmpty else {
            return """
            INTENTIONAL UNDERSTANDING (timing):
            Reverse bar logic — one-word calibration taps measure how fast Jim commits intention, not just what he picks. \
            AI is weak on time; this layer fixes that hole. Long pause = likely hard to say one thing (temporal binding, weight). \
            Rush = likely confident pattern. Still calibrating personal tempo.
            """
        }

        let lines = recent.map { "- \($0.inference)" }.joined(separator: "\n")
        let median = Int(tempo.globalMedianTapMs)
        let last = observations.last!

        return """
        INTENTIONAL UNDERSTANDING (timing):
        Reverse bar logic — speed + choice together. Personal median tap: \(median)ms (n=\(tempo.sampleCount)). \
        Last tempo: \(last.tempo.rawValue). Do not treat silence as idle. Gaps are Jim's rhythm data.

        Recent timing:
        \(lines)
        """
    }

    var observationCount: Int { observations.count }

    // MARK: - Private

    private func gapSinceLast(from now: Date) -> Int {
        defer { lastEventAt = now }
        guard let last = lastEventAt else { return 0 }
        return Int(now.timeIntervalSince(last) * 1000)
    }

    private func updateBaseline(latencyMs: Double, context: String) {
        guard latencyMs > 200, latencyMs < 60_000 else { return }
        tempo.sampleCount += 1
        tempo.globalMedianTapMs = ema(tempo.globalMedianTapMs, latencyMs, weight: 0.15)
        let prior = tempo.perContextMedian[context] ?? tempo.globalMedianTapMs
        tempo.perContextMedian[context] = ema(prior, latencyMs, weight: 0.25)
    }

    private func ema(_ current: Double, _ sample: Double, weight: Double) -> Double {
        current * (1 - weight) + sample * weight
    }

    private func inferenceForTap(tempo: TempoClass, latencyMs: Int, label: String, confirmed: Bool) -> String {
        let sec = Double(latencyMs) / 1000.0
        let answer = confirmed ? "yes" : "no"
        switch tempo {
        case .rush:
            return String(format: "Rush %.1fs → %@ on \"%@\" — confident commit.", sec, answer, label)
        case .deliberate:
            return String(format: "Deliberate %.1fs → %@ on \"%@\" — normal personal tempo.", sec, answer, label)
        case .stall:
            return String(format: "Stall %.1fs → %@ on \"%@\" — hard to say one thing; weight or temporal binding.", sec, answer, label)
        case .unknown:
            return "Tap on \"\(label)\" (\(answer))."
        }
    }

    private func append(_ obs: TimingObservation) {
        observations.append(obs)
        if observations.count > maxObservations {
            observations.removeFirst(observations.count - maxObservations)
        }
    }

    private struct Storage: Codable {
        let observations: [TimingObservation]
        let tempo: PersonalTempo
    }

    private func save() {
        let storage = Storage(observations: observations, tempo: tempo)
        guard let data = try? JSONEncoder().encode(storage) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let storage = try? JSONDecoder().decode(Storage.self, from: data) else { return }
        observations = storage.observations
        tempo = storage.tempo
        lastEventAt = observations.last?.timestamp
    }
}