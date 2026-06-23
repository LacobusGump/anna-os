import Foundation
import Speech
import AVFoundation

/// Captures what Jim says right after "Hey Anna" (e.g. "I'm making an omelet").
final class SpeechCaptureEngine {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    func captureUtterance(maxSeconds: TimeInterval = 4, completion: @escaping (String) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard status == .authorized, let self, let recognizer = self.recognizer, recognizer.isAvailable else {
                DispatchQueue.main.async { completion("") }
                return
            }
            self.runCapture(recognizer: recognizer, maxSeconds: maxSeconds, completion: completion)
        }
    }

    private func runCapture(
        recognizer: SFSpeechRecognizer,
        maxSeconds: TimeInterval,
        completion: @escaping (String) -> Void
    ) {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        var best = ""
        var task: SFSpeechRecognitionTask?

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            engine.prepare()
            try engine.start()
        } catch {
            DispatchQueue.main.async { completion("") }
            return
        }

        task = recognizer.recognitionTask(with: request) { result, error in
            if let result {
                best = result.bestTranscription.formattedString
                if result.isFinal {
                    self.finish(engine: engine, request: request, task: task, text: best, completion: completion)
                }
            }
            if error != nil {
                self.finish(engine: engine, request: request, task: task, text: best, completion: completion)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + maxSeconds) {
            self.finish(engine: engine, request: request, task: task, text: best, completion: completion)
        }
    }

    private func finish(
        engine: AVAudioEngine,
        request: SFSpeechAudioBufferRecognitionRequest,
        task: SFSpeechRecognitionTask?,
        text: String,
        completion: @escaping (String) -> Void
    ) {
        task?.cancel()
        request.endAudio()
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        let cleaned = text
            .replacingOccurrences(of: "(?i)hey anna[, ]*", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        DispatchQueue.main.async { completion(cleaned) }
    }
}