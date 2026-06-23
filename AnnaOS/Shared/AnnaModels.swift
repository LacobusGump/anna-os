import Foundation

struct SensorState: Codable {
    var heartRate: Double = 72.0
    var barometer: Double = 101325.0
    var acceleration: Double = 0.0
    var gyroscope: Double = 0.0
    var audioLevel: Double = 0.0
    var isSleeping: Bool = false
    var timestamp: Date = Date()

    func inferContext() -> String {
        if isSleeping { return "sleeping" }
        if heartRate > 100 && acceleration > 0.5 { return "exercising" }
        if heartRate > 85 && acceleration < 0.1 { return "stressed" }
        if acceleration > 1.5 { return "falling" }
        return "quiet"
    }
}

struct AudioSample: Codable {
    var waveform: [Double]
    var spectrum: [Double]
    var containsWakeWord: Bool = false

    func detectEnvironment() -> String {
        let dominant = spectrum.max() ?? 0
        if dominant > 0.8 { return "stove" }
        if dominant > 0.5 { return "fridge" }
        if dominant > 0.2 { return "water" }
        return "quiet"
    }
}

struct ContextGuess: Codable, Identifiable {
    var id: String { label }
    let label: String
    let confidence: Double
    let question: String
}

struct LabeledAudioSample: Codable {
    let waveform: [Double]
    let spectrum: [Double]
    let label: String
    let timestamp: Date
    let hr: Double
    let barometer: Double
    let accel: Double
}

struct MemoryStats: Codable {
    let totalLabeled: Int
    let contextCounts: [String: Int]
    let confidence: Double
}

struct Song: Identifiable, Equatable, Codable {
    let id: UUID
    let title: String
    let subtitle: String
    let filename: String
    let cdnPath: String
    let trackNumber: Int

    init(title: String, subtitle: String, filename: String, cdnPath: String, trackNumber: Int) {
        self.id = UUID()
        self.title = title
        self.subtitle = subtitle
        self.filename = filename
        self.cdnPath = cdnPath
        self.trackNumber = trackNumber
    }

    var streamURL: URL {
        URL(string: MusicCDN.base + cdnPath + filename)!
    }
}

enum MusicCDN {
    static let base = "https://cdn.jsdelivr.net/gh/LacobusGump/music2.0@main"
    static let james = "/v5/james/"
    static let ai = "/v5/ai/"
}

struct ToolResult: Codable {
    let tool: String
    let status: String
    let result: String
    let confidence: Double
}