import Foundation

/// Know Jim's voice vs someone else's — spectral fingerprint from wrist mic.
/// Calibrates from Hey Anna + confirmed "talking" taps. Trust function: notes tag speaker.
enum NoteSpeaker: String, Codable, CaseIterable {
    case jim
    case other
    case anna
    case unknown
}

final class VoiceIdentity {
    static let shared = VoiceIdentity()

    private var jimCentroid: [Double] = []
    private var jimSampleCount: Int = 0
    private let storageURL: URL

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("anna_voice_identity.json")
        load()
    }

    func calibrateJim(from sample: AudioSample) {
        guard !sample.spectrum.isEmpty else { return }
        if jimCentroid.isEmpty {
            jimCentroid = sample.spectrum
        } else {
            jimCentroid = zip(jimCentroid, sample.spectrum).map { ($0 * 0.85) + ($1 * 0.15) }
        }
        jimSampleCount += 1
        save()
    }

    func classify(audio: AudioSample) -> (speaker: NoteSpeaker, confidence: Double) {
        guard jimSampleCount >= 3, !jimCentroid.isEmpty, !audio.spectrum.isEmpty else {
            return (.unknown, 0)
        }
        let sim = spectralSimilarity(audio.spectrum, jimCentroid)
        if sim >= 0.72 { return (.jim, sim) }
        if sim <= 0.45 { return (.other, 1 - sim) }
        return (.unknown, sim)
    }

    var isCalibrated: Bool { jimSampleCount >= 3 }

    func contextBlock() -> String {
        if isCalibrated {
            return "VOICE ID: Jim fingerprint calibrated (n=\(jimSampleCount)). Transcripts tag jim vs other when mic confidence allows."
        }
        return "VOICE ID: still calibrating Jim's voice from Hey Anna + talking context — speaker may be unknown until n≥3."
    }

    private func spectralSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        let n = min(a.count, b.count)
        guard n > 0 else { return 0 }
        var dot = 0.0, na = 0.0, nb = 0.0
        for i in 0..<n {
            dot += a[i] * b[i]
            na += a[i] * a[i]
            nb += b[i] * b[i]
        }
        let denom = sqrt(na) * sqrt(nb)
        return denom > 0 ? dot / denom : 0
    }

    private struct Stored: Codable {
        var jimCentroid: [Double]
        var jimSampleCount: Int
    }

    private func save() {
        let stored = Stored(jimCentroid: jimCentroid, jimSampleCount: jimSampleCount)
        guard let data = try? JSONEncoder().encode(stored) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let stored = try? JSONDecoder().decode(Stored.self, from: data) else { return }
        jimCentroid = stored.jimCentroid
        jimSampleCount = stored.jimSampleCount
    }
}