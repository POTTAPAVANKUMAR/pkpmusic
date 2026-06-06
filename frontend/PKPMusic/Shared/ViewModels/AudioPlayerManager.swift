import Foundation
import AVFoundation
import MediaPlayer

class AudioPlayerManager: ObservableObject {
    static let shared = AudioPlayerManager()
    
    private var player: AVPlayer?
    private var timeObserver: Any?
    
    @Published var isPlaying = false
    @Published var currentSong: Song?
    @Published var progress: Double = 0.0
    @Published var duration: Double = 0.0
    
    private var queue: [Song] = []
    private var currentIndex: Int = 0
    
    init() {
        setupRemoteTransportControls()
    }
    
    func play(song: Song, in queue: [Song] = [], at index: Int = 0) {
        guard let url = NetworkManager.shared.getStreamURL(for: song.id) else { return }
        
        self.queue = queue.isEmpty ? [song] : queue
        self.currentIndex = queue.isEmpty ? 0 : index
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category.")
        }
        
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.play()
        
        isPlaying = true
        currentSong = song
        progress = 0.0
        
        updateNowPlayingInfo(song: song)
        NetworkManager.shared.recordHistory(songId: song.id)
        
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinishPlaying), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        setupTimeObserver()
    }
    
    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, let item = self.player?.currentItem else { return }
            self.progress = time.seconds
            if !item.duration.isIndefinite {
                self.duration = item.duration.seconds
            }
        }
    }
    
    func seek(to time: Double) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 1000))
    }
    
    @objc private func playerDidFinishPlaying(note: NSNotification) {
        playNext()
    }
    
    func playNext() {
        guard !queue.isEmpty, currentIndex < queue.count - 1 else { return }
        currentIndex += 1
        play(song: queue[currentIndex], in: queue, at: currentIndex)
    }
    
    func playPrevious() {
        guard !queue.isEmpty, currentIndex > 0 else {
            seek(to: 0)
            return
        }
        currentIndex -= 1
        play(song: queue[currentIndex], in: queue, at: currentIndex)
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
        commandCenter.playCommand.addTarget { [unowned self] _ in
            self.resume()
            return .success
        }
        commandCenter.pauseCommand.addTarget { [unowned self] _ in
            self.pause()
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { [unowned self] _ in
            self.playNext()
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [unowned self] _ in
            self.playPrevious()
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
