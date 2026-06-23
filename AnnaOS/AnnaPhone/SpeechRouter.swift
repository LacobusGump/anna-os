import AVFoundation

final class SpeechRouter {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)

        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.52
        utterizerVoice(utterance)
        synthesizer.speak(utterance)
    }

    private func utterizerVoice(_ utterance: AVSpeechUtterance) {
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
    }
}