import Foundation
import AVFoundation
import Accelerate

protocol AudioCapturing: AnyObject {
    var onWakeWord: (() -> Void)? { get set }
    func start() throws
    func stop()
    func currentSample() -> AudioSample
}

final class AudioCaptureEngine: AudioCapturing {
    var onWakeWord: (() -> Void)?

    private let engine = AVAudioEngine()
    private var waveform: [Double] = Array(repeating: 0, count: 1024)
    private var spectrum: [Double] = Array(repeating: 0, count: 64)
    private var audioLevel: Double = 0
    private var wakeWordCooldown = false
    private let wakePhrases = ["hey anna", "anna"]

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .allowBluetoothHFP])
        try session.setActive(true)

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        let bufferSize: AVAudioFrameCount = 1024

        input.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
            self?.processBuffer(buffer)
        }

        engine.prepare()
        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    func currentSample() -> AudioSample {
        AudioSample(waveform: waveform, spectrum: spectrum, containsWakeWord: false)
    }

    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }

        var samples = [Float](repeating: 0, count: min(frameCount, 1024))
        for i in 0..<samples.count {
            samples[i] = channelData[i]
        }

        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        audioLevel = Double(rms)

        waveform = samples.map { Double($0) }
        spectrum = computeSpectrum(waveform)

        if audioLevel > 0.02 && !wakeWordCooldown {
            detectWakeWordEnergy()
        }
    }

    private func computeSpectrum(_ waveform: [Double]) -> [Double] {
        var spec = Array(repeating: 0.0, count: 64)
        for (i, sample) in waveform.enumerated() {
            let bucket = min((i * 64) / max(waveform.count, 1), 63)
            spec[bucket] += abs(sample) / Double(waveform.count)
        }
        return spec
    }

    /// Energy spike in speech band triggers wake — phone confirms via Claude path.
    /// Real on-device Speech on watch is limited; this is the v1 gate.
    private func detectWakeWordEnergy() {
        let speechEnergy = spectrum[10..<40].reduce(0, +)
        guard speechEnergy > 0.15 else { return }

        wakeWordCooldown = true
        DispatchQueue.main.async { [weak self] in
            self?.onWakeWord?()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.wakeWordCooldown = false
        }
    }
}