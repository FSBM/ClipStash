import AVFoundation

/// Plays the app open/close sound.
final class SoundPlayer {
    static let shared = SoundPlayer()
    private var player: AVAudioPlayer?

    func playOpenSound() {
        let resourcePath = Bundle.main.resourcePath ?? ""
        let url = URL(fileURLWithPath: resourcePath + "/open-sound.mp3")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.volume = 0.5
        player?.play()
    }
}
