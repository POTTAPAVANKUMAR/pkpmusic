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
    
    @Published var isShuffled = false
    @Published var isAutoPlayEnabled = true
    
    enum RepeatMode {
        case off, all, one
    }
    @Published var repeatMode: RepeatMode = .off
    
    private var originalQueue: [Song] = []
    var queue: [Song] = []
    private var currentIndex: Int = 0
    
    init() {
        setupRemoteTransportControls()
    }
    
    func playSong(songId: String) {
        let tempSong = Song(id: songId, title: "Shared Song", artist: "Unknown", album: nil, durationMs: nil, coverArtUrl: nil)
        play(song: tempSong)
    }
    
    func play(song: Song, in newQueue: [Song] = [], at index: Int = 0) {
        let url: URL
        if let localUrl = DownloadManager.shared.localURL(for: song.id) {
            url = localUrl
        } else if let remoteUrl = NetworkManager.shared.getStreamURL(for: song.id) {
            url = remoteUrl
        } else {
            return
        }
        
        if !newQueue.isEmpty {
            self.originalQueue = newQueue
            if isShuffled {
                shuffleQueue(startingWith: song)
            } else {
                self.queue = newQueue
                self.currentIndex = index
            }
        } else if self.queue.isEmpty {
            self.originalQueue = [song]
            self.queue = [song]
            self.currentIndex = 0
        }
        
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
    
    func toggleShuffle() {
        isShuffled.toggle()
        if isShuffled, let current = currentSong {
            shuffleQueue(startingWith: current)
        } else if let current = currentSong, let idx = originalQueue.firstIndex(where: { $0.id == current.id }) {
            queue = originalQueue
            currentIndex = idx
        }
    }
    
    func toggleRepeat() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }
    
    private func shuffleQueue(startingWith song: Song) {
        var remaining = originalQueue.filter { $0.id != song.id }
        remaining.shuffle() // Fisher-Yates built-in to Swift
        queue = [song] + remaining
        currentIndex = 0
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
        if repeatMode == .one {
            seek(to: 0)
            resume()
        } else {
            playNext(isAutoPlay: true)
        }
    }
    
    func playNext(isAutoPlay: Bool = false) {
        guard !queue.isEmpty else { return }
        
        if currentIndex < queue.count - 1 {
            currentIndex += 1
            play(song: queue[currentIndex])
            
            // Pre-fetch more songs if we are nearing the end of the queue
            if isAutoPlayEnabled && currentIndex == queue.count - 2 {
                fetchMoreForUpNext()
            }
        } else if isAutoPlayEnabled && isAutoPlay {
            // Reached the end, fetch up next and wait
            pause()
            fetchMoreForUpNext { [weak self] success in
                guard let self = self else { return }
                if success && self.currentIndex < self.queue.count - 1 {
                    self.currentIndex += 1
                    self.play(song: self.queue[self.currentIndex])
                } else if self.repeatMode == .all || self.isShuffled {
                    self.currentIndex = 0
                    self.play(song: self.queue[self.currentIndex])
                } else {
                    self.seek(to: 0)
                }
            }
        } else if repeatMode == .all || (!isAutoPlay && isShuffled) {
            currentIndex = 0
            play(song: queue[currentIndex])
        } else {
            pause()
            seek(to: 0)
        }
    }
    
    private func fetchMoreForUpNext(completion: ((Bool) -> Void)? = nil) {
        guard let lastSong = queue.last else {
            completion?(false)
            return
        }
        
        NetworkManager.shared.fetchUpNext(videoId: lastSong.id) { [weak self] newSongs in
            guard let self = self else { return }
            
            let uniqueSongs = newSongs.filter { s in !self.queue.contains(where: { $0.id == s.id }) }
            if !uniqueSongs.isEmpty {
                self.queue.append(contentsOf: uniqueSongs)
                self.originalQueue.append(contentsOf: uniqueSongs)
                completion?(true)
            } else {
                completion?(false)
            }
        }
    }
    
    func playPrevious() {
        guard !queue.isEmpty else { return }
        if progress > 3.0 || currentIndex == 0 {
            seek(to: 0)
        } else {
            currentIndex -= 1
            play(song: queue[currentIndex])
        }
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
