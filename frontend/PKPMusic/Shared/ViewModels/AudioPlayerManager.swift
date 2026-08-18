import Foundation
import AVFoundation
import MediaPlayer
#if os(iOS)
import UIKit
#endif

class AudioPlayerManager: ObservableObject {
    static let shared = AudioPlayerManager()
    
    private var player: AVPlayer?
    private var timeObserver: Any?
    
    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var playbackError: String?
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
    @Published var queue: [Song] = []
    @Published var currentIndex: Int = 0
    
    private var statusObservation: NSKeyValueObservation?
    private var bufferObservation: NSKeyValueObservation?
    private var likelyToKeepUpObservation: NSKeyValueObservation?
    private var retryWorkItem: DispatchWorkItem?
    
    init() {
        setupRemoteTransportControls()
    }
    
    func playSong(songId: String) {
        let tempSong = Song(id: songId, title: "Shared Song", artist: "Unknown", album: nil, albumId: nil, durationMs: nil, coverArtUrl: nil)
        play(song: tempSong)
    }
    
    private func cleanupCurrentPlayer() {
        retryWorkItem?.cancel()
        retryWorkItem = nil
        
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: nil)
        
        statusObservation?.invalidate()
        statusObservation = nil
        bufferObservation?.invalidate()
        bufferObservation = nil
        likelyToKeepUpObservation?.invalidate()
        likelyToKeepUpObservation = nil
    }
    
    func play(song: Song, in newQueue: [Song] = [], at index: Int = 0) {
        cleanupCurrentPlayer()
        
        let url: URL
        if let localUrl = DownloadManager.shared.localURL(for: song.id) {
            url = localUrl
        } else if let remoteUrl = NetworkManager.shared.getStreamURL(for: song.id) {
            url = remoteUrl
        } else {
            self.playbackError = "Invalid song URL"
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
            print("Failed to set audio session category: \(error)")
        }
        
        let playerItem = AVPlayerItem(url: url)
        playerItem.preferredForwardBufferDuration = 5.0
        
        player = AVPlayer(playerItem: playerItem)
        player?.automaticallyWaitsToMinimizeStalling = true
        
        isPlaying = true
        isLoading = true
        playbackError = nil
        currentSong = song
        progress = 0.0
        duration = Double(song.durationMs ?? 0) / 1000.0
        
        updateNowPlayingInfo(song: song)
        NetworkManager.shared.recordHistory(songId: song.id)
        
        // Observe Player Item Status (Ready, Failed)
        statusObservation = playerItem.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch item.status {
                case .readyToPlay:
                    self.isLoading = false
                    self.playbackError = nil
                    if !item.duration.isIndefinite && item.duration.seconds > 0 {
                        self.duration = item.duration.seconds
                        self.updateNowPlayingPlaybackState()
                    }
                case .failed:
                    self.isLoading = false
                    let errMsg = item.error?.localizedDescription ?? "Unknown audio playback error"
                    print("Playback failed for \(song.title): \(errMsg)")
                    self.playbackError = "Could not load audio. Skipping..."
                    
                    // Auto-skip to next song on failure after brief pause
                    let workItem = DispatchWorkItem { [weak self] in
                        guard let self = self, self.currentSong?.id == song.id else { return }
                        self.playNext(isAutoPlay: true)
                    }
                    self.retryWorkItem = workItem
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: workItem)
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }
        
        // Observe Buffering State
        likelyToKeepUpObservation = playerItem.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if item.isPlaybackLikelyToKeepUp {
                    self.isLoading = false
                }
            }
        }
        
        bufferObservation = playerItem.observe(\.isPlaybackBufferEmpty, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if item.isPlaybackBufferEmpty && self.isPlaying {
                    self.isLoading = true
                }
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinishPlaying), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        NotificationCenter.default.addObserver(self, selector: #selector(playerFailedToPlayToEnd), name: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
        
        setupTimeObserver()
        player?.play()
        
        // Prefetch next song stream for gapless playback
        prefetchNextSongStream()
    }
    
    @objc private func playerFailedToPlayToEnd(note: NSNotification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("Song failed to play to end.")
            self.playNext(isAutoPlay: true)
        }
    }
    
    private func prefetchNextSongStream() {
        guard !queue.isEmpty, currentIndex + 1 < queue.count else { return }
        let nextSong = queue[currentIndex + 1]
        
        // Only prefetch if not downloaded
        if !DownloadManager.shared.isDownloaded(songId: nextSong.id) {
            NetworkManager.shared.prefetchStream(videoId: nextSong.id)
        }
    }
    
    // MARK: - Queue Management
    
    func insertNext(song: Song) {
        if queue.isEmpty {
            play(song: song)
        } else {
            // Insert after current index
            let insertIndex = currentIndex + 1
            if insertIndex < queue.count {
                queue.insert(song, at: insertIndex)
            } else {
                queue.append(song)
            }
            // If we are currently playing, prefetching is already handled for the *old* next song.
            // But if the user clicks Play Next, we should probably prefetch this one.
            if currentIndex + 1 < queue.count && queue[currentIndex + 1].id == song.id {
                prefetchNextSongStream()
            }
        }
    }
    
    func addToQueue(song: Song) {
        if queue.isEmpty {
            play(song: song)
        } else {
            queue.append(song)
            // If this is the only song we added next, prefetch it
            if currentIndex + 1 == queue.count - 1 {
                prefetchNextSongStream()
            }
        }
    }
    
    func playSongInQueue(at index: Int) {
        guard index >= 0 && index < queue.count else { return }
        currentIndex = index
        play(song: queue[index])
    }
    
    func removeFromQueue(at index: Int) {
        guard index >= 0 && index < queue.count else { return }
        if index == currentIndex {
            playNext(isAutoPlay: true)
        } else {
            queue.remove(at: index)
            if index < currentIndex {
                currentIndex -= 1
            }
        }
    }
    
    func moveInQueue(from source: IndexSet, to destination: Int) {
        queue.move(fromOffsets: source, toOffset: destination)
        if let current = currentSong, let newIdx = queue.firstIndex(where: { $0.id == current.id }) {
            currentIndex = newIdx
        }
    }
    
    func clearUpcomingQueue() {
        guard !queue.isEmpty else { return }
        if currentIndex < queue.count {
            queue = Array(queue[0...currentIndex])
        }
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
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 1000)) { [weak self] _ in
            self?.updateNowPlayingPlaybackState()
        }
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
        updateNowPlayingPlaybackState()
    }
    
    func resume() {
        player?.play()
        isPlaying = true
        updateNowPlayingPlaybackState()
    }
    
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Remove existing targets if any
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
        commandCenter.changeShuffleModeCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        
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
        commandCenter.changeShuffleModeCommand.addTarget { [unowned self] event in
            guard let shuffleEvent = event as? MPChangeShuffleModeCommandEvent else { return .commandFailed }
            self.isShuffled = (shuffleEvent.shuffleType != .off)
            if self.isShuffled, let current = self.currentSong {
                self.shuffleQueue(startingWith: current)
            } else if let current = self.currentSong, let idx = self.originalQueue.firstIndex(where: { $0.id == current.id }) {
                self.queue = self.originalQueue
                self.currentIndex = idx
            }
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.addTarget { [unowned self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self.seek(to: positionEvent.positionTime)
            return .success
        }
    }
    
    private func updateNowPlayingInfo(song: Song) {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = song.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = song.artist
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = progress
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        
        #if os(iOS)
        if let urlString = song.coverArtUrl, let url = URL(string: urlString) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in return image }
                    DispatchQueue.main.async {
                        var currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
                        currentInfo[MPMediaItemPropertyArtwork] = artwork
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = currentInfo
                    }
                }
            }.resume()
        }
        #endif
    }
    
    private func updateNowPlayingPlaybackState() {
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
        
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = progress
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}
