import AVFoundation
import Foundation

final class WatchAudioRouter {
    private let synthesizer = AVSpeechSynthesizer()
    private var player: AVPlayer?
    private var playerObserver: NSObjectProtocol?

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.52
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }

    func play(_ song: Song) {
        pause()
        let item = AVPlayerItem(url: song.streamURL)
        player = AVPlayer(playerItem: item)
        player?.play()
    }

    func pause() {
        player?.pause()
        player = nil
    }
}