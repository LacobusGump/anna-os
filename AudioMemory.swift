import Foundation

// MARK: - Audio Memory: The Learning System

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

    // MARK: - Learning: Record + Label

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
    }

    func recordCorrection(audio: AudioSample, userLabel: String, algoGuess: String) {
        // Store as negative example for the wrong guess
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
    }

    // MARK: - Guessing: Top 3 Context Predictions

    func generateGuesses(audio: AudioSample, sensorContext: String) -> [ContextGuess] {
        var guesses: [ContextGuess] = []

        // Simple Bayesian: find closest labeled samples by spectrum similarity
        let scores = scoreContexts(audio: audio, sensors: sensorContext)

        // Sort by confidence
        let sorted = scores.sorted { $0.value > $1.value }

        // Return top 3
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

        // For each known context, score how likely this audio matches
        for context in contextDistribution.keys {
            let samplesForContext = labeledSamples.filter { $0.label == context }

            if samplesForContext.isEmpty {
                scores[context] = 0.1  // No prior knowledge, low confidence
                continue
            }

            // Score = avg similarity to past samples of this context
            let similarities = samplesForContext.map { spectralSimilarity(audio.spectrum, $0.spectrum) }
            let avgSimilarity = similarities.reduce(0, +) / Double(similarities.count)

            // Boost by prior: more samples = more confidence in this category
            let priorBoost = Double(samplesForContext.count) / Double(labeledSamples.count + 1)
            scores[context] = avgSimilarity * (1.0 + priorBoost * 0.3)
        }

        return scores
    }

    private func spectralSimilarity(_ spec1: [Double], _ spec2: [Double]) -> Double {
        guard spec1.count == spec2.count else { return 0.0 }

        // Cosine similarity on spectrogram
        let dotProduct = zip(spec1, spec2).map(*).reduce(0, +)
        let norm1 = sqrt(spec1.map { $0 * $0 }.reduce(0, +))
        let norm2 = sqrt(spec2.map { $0 * $0 }.reduce(0, +))

        guard norm1 > 0 && norm2 > 0 else { return 0.0 }
        return dotProduct / (norm1 * norm2)
    }

    private func questionFor(context: String) -> String {
        switch context {
        case "cooking":
            return "Are you cooking?"
        case "coding":
            return "Working on code?"
        case "sleeping":
            return "Time to sleep?"
        case "building":
            return "Building something?"
        case "talking":
            return "On a call?"
        default:
            return "What's happening?"
        }
    }

    private func fallbackGuesses() -> [ContextGuess] {
        return [
            ContextGuess(label: "quiet", confidence: 0.6, question: "Just listening?"),
            ContextGuess(label: "working", confidence: 0.4, question: "Focused time?"),
            ContextGuess(label: "relaxing", confidence: 0.3, question: "Taking a break?")
        ]
    }

    // MARK: - Most Likely Context (for Claude)

    func getMostLikelyContext() -> String {
        // Return the context with most labels
        guard let (context, _) = contextDistribution.max(by: { $0.value < $1.value }) else {
            return "quiet"
        }
        return context
    }

    // MARK: - Memory Stats

    func stats() -> MemoryStats {
        return MemoryStats(
            totalLabeled: labeledSamples.count,
            contextCounts: contextDistribution,
            confidence: Double(labeledSamples.count) / Double(labeledSamples.count + 10)  // 0-1 scale
        )
    }
}

// MARK: - Models

struct ContextGuess {
    let label: String
    let confidence: Double  // 0.0 to 1.0
    let question: String   // "Are you cooking?" "Working on code?" "Time to sleep?"
}

struct LabeledAudioSample {
    let waveform: [Double]
    let spectrum: [Double]
    let label: String
    let timestamp: Date
    let hr: Double
    let barometer: Double
    let accel: Double
}

struct MemoryStats {
    let totalLabeled: Int
    let contextCounts: [String: Int]
    let confidence: Double
}
