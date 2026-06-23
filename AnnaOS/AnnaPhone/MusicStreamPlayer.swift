import AVFoundation
import Foundation

final class MusicStreamPlayer: ObservableObject {
    @Published var isPlaying = false
    @Published var currentSong: Song?

    private var player: AVPlayer?
    private let library = MusicLibrary()

    func play(filename: String) {
        guard AnnaSecurity.musicStreamEnabled else { return }
        guard let song = library.findSong(byFilename: filename) ?? library.findSong(filename) else { return }
        guard NetworkGuard.isAllowed(song.streamURL) else { return }
        NetworkGuard.logEgress(url: song.streamURL, kind: .musicCDN)
        currentSong = song
        let item = AVPlayerItem(url: song.streamURL)
        player = AVPlayer(playerItem: item)
        player?.play()
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }
}