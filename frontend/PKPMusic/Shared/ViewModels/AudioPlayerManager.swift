import Foundation
import AVFoundation
import MediaPlayer

class AudioPlayerManager: ObservableObject {
    static let shared = AudioPlayerManager()
    
    private var player: AVPlayer?
    @Published var isPlaying = false
    @Published var currentSong: Song?
    
    init() {
        setupRemoteTransportControls()
    }
    
    func play(song: Song) {
        guard let url = NetworkManager.shared.getStreamURL(for: song.id) else { return }
        
        // Configure audio session for background playback
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category.")
        }
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.play()
        
        isPlaying = true
        currentSong = song
        
        updateNowPlayingInfo(song: song)
        
        // Record History
        NetworkManager.shared.recordHistory(songId: song.id)
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    func resume() {
        player?.play()
        isPlaying = true
    }
    
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [unowned self] event in
            self.resume()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [unowned self] event in
            self.pause()
            return .success
        }
    }
    
    private func updateNowPlayingInfo(song: Song) {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = song.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = song.artist
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}
