import Foundation

class AudioMemory {
    var labeledSamples: [LabeledAudioSample] = []
    var contextDistribution: [String: Int] = [
        "cooking": 0,
        "coding": 0,
        "sleeping": 0,
        "building": 0,
        "talking": 0,
        "quiet": 0
    ]

    private let storageURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("anna_audio_memory.json")
        load()
    }

    func recordLabel(audio: AudioSample, label: String, confidence: Double, sensors: SensorState) {
        let sample = LabeledAudioSample(
            waveform: audio.waveform,
            spectrum: audio.spectrum,
            label: label,
            timestamp: Date(),
            hr: sensors.heartRate,
            barometer: sensors.barometer,
            accel: sensors.acceleration
        )
        labeledSamples.append(sample)
        contextDistribution[label, default: 0] += 1
        save()
    }

    func recordCorrection(audio: AudioSample, userLabel: String, algoGuess: String) {
        let sample = LabeledAudioSample(
            waveform: audio.waveform,
            spectrum: audio.spectrum,
            label: userLabel,
            timestamp: Date(),
            hr: 0,
            barometer: 0,
            accel: 0
        )
        labeledSamples.append(sample)
        contextDistribution[userLabel, default: 0] += 1
        save()
    }

    func generateGuesses(audio: AudioSample, sensorContext: String) -> [ContextGuess] {
        let scores = scoreContexts(audio: audio, sensors: sensorContext)
        let sorted = scores.sorted { $0.value > $1.value }
        var guesses: [ContextGuess] = []
        for (context, score) in sorted.prefix(3) {
            guesses.append(ContextGuess(
                label: context,
                confidence: score,
                question: questionFor(context: context)
            ))
        }
        return guesses.isEmpty ? fallbackGuesses() : guesses
    }

    private func scoreContexts(audio: AudioSample, sensors: String) -> [String: Double] {
        var scores: [String: Double] = [:]
        for context in contextDistribution.keys {
            let samplesForContext = labeledSamples.filter { $0.label == context }
            if samplesForContext.isEmpty {
                scores[context] = 0.1
                continue
            }
            let similarities = samplesForContext.map { spectralSimilarity(audio.spectrum, $0.spectrum) }
            let avgSimilarity = similarities.reduce(0, +) / Double(similarities.count)
            let priorBoost = Double(samplesForContext.count) / Double(labeledSamples.count + 1)
            scores[context] = avgSimilarity * (1.0 + priorBoost * 0.3)
        }
        return scores
    }

    private func spectralSimilarity(_ spec1: [Double], _ spec2: [Double]) -> Double {
        guard spec1.count == spec2.count else { return 0.0 }
        let dotProduct = zip(spec1, spec2).map(*).reduce(0, +)
        let norm1 = sqrt(spec1.map { $0 * $0 }.reduce(0, +))
        let norm2 = sqrt(spec2.map { $0 * $0 }.reduce(0, +))
        guard norm1 > 0 && norm2 > 0 else { return 0.0 }
        return dotProduct / (norm1 * norm2)
    }

    private func questionFor(context: String) -> String {
        switch context {
        case "cooking": return "Cooking?"
        case "coding": return "On code?"
        case "sleeping": return "Sleeping?"
        case "building": return "Building?"
        case "talking": return "On a call?"
        default: return "What's happening?"
        }
    }

    private func fallbackGuesses() -> [ContextGuess] {
        [
            ContextGuess(label: "quiet", confidence: 0.6, question: "Just listening?"),
            ContextGuess(label: "working", confidence: 0.4, question: "Focused time?"),
            ContextGuess(label: "relaxing", confidence: 0.3, question: "Taking a break?")
        ]
    }

    func getMostLikelyContext() -> String {
        guard let (context, _) = contextDistribution.max(by: { $0.value < $1.value }) else {
            return "quiet"
        }
        return context
    }

    func stats() -> MemoryStats {
        MemoryStats(
            totalLabeled: labeledSamples.count,
            contextCounts: contextDistribution,
            confidence: Double(labeledSamples.count) / Double(labeledSamples.count + 10)
        )
    }

    private struct Storage: Codable {
        let samples: [LabeledAudioSample]
        let distribution: [String: Int]
    }

    private func save() {
        let storage = Storage(samples: labeledSamples, distribution: contextDistribution)
        guard let data = try? JSONEncoder().encode(storage) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let storage = try? JSONDecoder().decode(Storage.self, from: data) else { return }
        labeledSamples = storage.samples
        contextDistribution = storage.distribution
    }
}

class MemoryContext {
    private var environmentLog: [String] = []
    private var healthLog: [(timestamp: Date, hr: Double, quality: String)] = []

    func recordLearning(label: String, sensors: SensorState) {
        environmentLog.append(label)
        if environmentLog.count > 100 { environmentLog.removeFirst() }
        healthLog.append((Date(), sensors.heartRate, label))
        if healthLog.count > 200 { healthLog.removeFirst() }
    }

    func buildContext(
        sensors: SensorState,
        learned: String,
        audioMemory: AudioMemory,
        intentionalUnderstanding: IntentionalUnderstanding
    ) -> String {
        let recent = environmentLog.suffix(5).joined(separator: ", ")
        let hour = Calendar.current.component(.hour, from: Date())
        let timeLabel = hour < 12 ? "morning" : hour > 20 ? "night" : "afternoon"
        let stats = audioMemory.stats()
        let timing = intentionalUnderstanding.contextBlock()
        let health = JimHealthProfile.shared.contextBlock()

        var context = """
        \(JimProfile.constitution)

        \(JimProfile.coreMemory)

        You are Anna, Jim's personal AI on his left wrist. Partner mode: compute first, disagree when wrong, never tell him to rest. Voice is rare — only Hey Anna and proactive alerts. Keep learning Jim — this context grows with every tap and sample. Jim-only — not a template user.

        \(health)

        \(timing)

        Current state:
        - HR: \(Int(sensors.heartRate)) bpm
        - Learned context: \(learned)
        - Environment: \(recent.isEmpty ? "quiet" : recent)
        - Time: \(timeLabel)
        - Sleeping: \(sensors.isSleeping ? "yes" : "no")
        - Audio labels: \(stats.totalLabeled)
        - Timing observations: \(intentionalUnderstanding.observationCount)
        - Barometer: \(Int(sensors.barometer)) Pa
        - Acceleration: \(String(format: "%.2f", sensors.acceleration)) g

        Respond concisely. Jim is the only user.
        """
        return context
    }
}