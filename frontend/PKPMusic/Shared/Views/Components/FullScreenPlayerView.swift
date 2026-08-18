import SwiftUI
import AVKit

enum PlayerSheet: Identifiable {
    case upNext, lyrics, related, album, options, playlists, videoQuality
    var id: Int {
        switch self {
        case .upNext: return 1
        case .lyrics: return 2
        case .related: return 3
        case .album: return 4
        case .options: return 5
        case .playlists: return 6
        case .videoQuality: return 7
        }
    }
}

struct FullScreenPlayerView: View {
    @StateObject private var audioManager = AudioPlayerManager.shared
    @StateObject private var networkManager = NetworkManager.shared
    @Binding var isShowing: Bool
    
    @State private var activeSheet: PlayerSheet? = nil
    
    var body: some View {
        ZStack {
            // Blurred Background
            if let song = audioManager.currentSong {
                AsyncImage(url: URL(string: song.coverArtUrl ?? "")) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Theme.SpiderBackground()
                }
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .clipped()
                .overlay(.ultraThinMaterial)
                .opacity(0.8)
                .ignoresSafeArea()
                
                Color.black.opacity(0.3).ignoresSafeArea()
            } else {
                Theme.SpiderBackground().ignoresSafeArea()
            }
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { isShowing = false }) {
                        Image(systemName: "chevron.down")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                    }
                    Spacer()
                    // Song / Video Toggle
                    HStack(spacing: 0) {
                        Button(action: {
                            withAnimation(.spring()) { audioManager.setVideoMode(false) }
                        }) {
                            Text("Song")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(audioManager.isVideoMode ? .white.opacity(0.5) : .white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(audioManager.isVideoMode ? Color.clear : Color.white.opacity(0.2))
                                .clipShape(Capsule())
                        }
                        
                        Button(action: {
                            withAnimation(.spring()) { audioManager.setVideoMode(true) }
                        }) {
                            Text("Video")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(audioManager.isVideoMode ? .white : .white.opacity(0.5))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(audioManager.isVideoMode ? Color.white.opacity(0.2) : Color.clear)
                                .clipShape(Capsule())
                        }
                    }
                    .background(Color.black.opacity(0.3))
                    .clipShape(Capsule())
                    
                    Spacer()
                    
                    Button(action: { activeSheet = .options }) {
                        Image(systemName: "ellipsis")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                .padding(.top, 10)
                
                Spacer(minLength: 20)
                
                // Media Area (16:9 for Video, Square for Song)
                if let song = audioManager.currentSong {
                    if audioManager.isVideoMode, let player = audioManager.player {
                        VideoPlayer(player: player)
                            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width * (9/16))
                            .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 10)
                            .disabled(true)
                    } else {
                        AsyncImage(url: URL(string: song.coverArtUrl ?? "")) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(Color.gray.opacity(0.2))
                        }
                        .frame(width: UIScreen.main.bounds.width - 60, height: UIScreen.main.bounds.width - 60)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 15)
                        .scaleEffect(audioManager.isPlaying ? 1.0 : 0.95)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: audioManager.isPlaying)
                    }
                    
                    Spacer(minLength: 30)
                    
                    // Song Info
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(song.title)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Text(song.artist)
                                .font(.title3)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                        Spacer()
                        
                        Button(action: { networkManager.addToFavorites(songId: song.id) }) {
                            Image(systemName: networkManager.favorites.contains(where: { $0.id == song.id }) ? "heart.fill" : "heart")
                                .font(.title)
                                .foregroundColor(Theme.spiderNeonRed)
                                .padding(10)
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    if let error = audioManager.playbackError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(Theme.spiderNeonRed)
                            .padding(.top, 4)
                    }
                    
                    // Scrubber
                    VStack(spacing: 8) {
                        Slider(value: Binding(get: {
                            audioManager.progress
                        }, set: { newValue in
                            audioManager.seek(to: newValue)
                        }), in: 0...(audioManager.duration > 0 ? audioManager.duration : 1))
                        .accentColor(.white)
                        
                        HStack {
                            Text(formatTime(audioManager.progress))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            Text(formatTime(audioManager.duration))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 20)
                    
                    // Playback Controls
                    HStack(spacing: 40) {
                        Button(action: { audioManager.toggleShuffle() }) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 20))
                                .foregroundColor(audioManager.isShuffled ? Theme.spiderNeonRed : .white.opacity(0.5))
                        }
                        
                        Button(action: { audioManager.playPrevious() }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                        }
                        
                        Button(action: {
                            if audioManager.isPlaying {
                                audioManager.pause()
                            } else {
                                audioManager.resume()
                            }
                        }) {
                            ZStack {
                                Image(systemName: audioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 70))
                                    .foregroundColor(.white)
                                    .opacity(audioManager.isLoading ? 0.35 : 1.0)
                                
                                if audioManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.spiderNeonRed))
                                        .scaleEffect(1.5)
                                }
                            }
                        }
                        
                        Button(action: { audioManager.playNext() }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                        }
                        
                        Button(action: { audioManager.toggleRepeat() }) {
                            Image(systemName: audioManager.repeatMode == .one ? "repeat.1" : "repeat")
                                .font(.system(size: 20))
                                .foregroundColor(audioManager.repeatMode == .off ? .white.opacity(0.5) : Theme.spiderNeonRed)
                        }
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    // Bottom Tabs
                    HStack {
                        Button(action: { activeSheet = .upNext }) {
                            Text("UP NEXT")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Button(action: { activeSheet = .lyrics }) {
                            Text("LYRICS")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Button(action: { activeSheet = .related }) {
                            Text("RELATED")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 30)
                }
            }
        }
        .gesture(DragGesture().onEnded { value in
            if value.translation.height > 100 {
                isShowing = false
            }
        })
        .confirmationDialog("Options", isPresented: Binding(
            get: { activeSheet == .options },
            set: { if !$0 { activeSheet = nil } }
        ), titleVisibility: .visible) {
            if let song = audioManager.currentSong {
                if audioManager.isVideoMode {
                    Button("Video Quality") {
                        // Using a slight delay to allow the first dialog to dismiss fully
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            activeSheet = .videoQuality
                        }
                    }
                }
                if DownloadManager.shared.isDownloaded(songId: song.id) {
                    Button("Remove Download", role: .destructive) {
                        DownloadManager.shared.removeDownload(songId: song.id)
                    }
                } else {
                    Button("Download") {
                        DownloadManager.shared.download(song: song)
                    }
                }
                if song.albumId != nil {
                    Button("Go to Album") { activeSheet = .album }
                }
                Button("Add to Playlist") {
                    networkManager.fetchPlaylists()
                    activeSheet = .playlists
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .confirmationDialog("Video Quality", isPresented: Binding(
            get: { activeSheet == .videoQuality },
            set: { if !$0 { activeSheet = nil } }
        ), titleVisibility: .visible) {
            Button("Auto (720p Recommended)" + (audioManager.videoQuality == "auto" ? " ✓" : "")) { audioManager.setVideoQuality("auto") }
            Button("720p" + (audioManager.videoQuality == "720p" ? " ✓" : "")) { audioManager.setVideoQuality("720p") }
            Button("360p" + (audioManager.videoQuality == "360p" ? " ✓" : "")) { audioManager.setVideoQuality("360p") }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $activeSheet) { sheetType in
            switch sheetType {
            case .upNext:
                QueueView(isShowing: Binding(get: { activeSheet == .upNext }, set: { if !$0 { activeSheet = nil } }))
                    .presentationDetents([.medium, .large])
            case .lyrics:
                LyricsView(song: audioManager.currentSong, isShowing: Binding(get: { activeSheet == .lyrics }, set: { if !$0 { activeSheet = nil } }))
                    .presentationDetents([.medium, .large])
            case .related:
                NavigationView {
                    if let song = audioManager.currentSong {
                        RelatedSongsView(videoId: song.id)
                    } else {
                        Text("No Song Playing")
                    }
                }
                .presentationDetents([.medium, .large])
            case .album:
                if let song = audioManager.currentSong, let albumId = song.albumId {
                    NavigationView {
                        AlbumDetailView(albumId: albumId)
                            .navigationBarItems(leading: Button("Close") { activeSheet = nil })
                    }
                }
            case .playlists:
                NavigationView {
                    List {
                        if networkManager.playlists.isEmpty {
                            Text("No playlists found.").foregroundColor(.gray)
                        } else {
                            ForEach(networkManager.playlists, id: \.id) { playlist in
                                Button(action: {
                                    if let song = audioManager.currentSong {
                                        networkManager.addSongToPlaylist(songId: song.id, playlistId: playlist.id)
                                    }
                                    activeSheet = nil
                                }) {
                                    Text(playlist.name).foregroundColor(.white)
                                }
                            }
                        }
                    }
                    .navigationTitle("Select Playlist")
                    .navigationBarItems(trailing: Button("Cancel") { activeSheet = nil })
                }
            case .options, .videoQuality:
                EmptyView() // Handled by confirmationDialog
            }
        }
    }
    
    private func formatTime(_ time: Double) -> String {
        guard time.isFinite && !time.isNaN else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    let time: Double
    let text: String
}

// LYRICS VIEW
struct LyricsView: View {
    let song: Song?
    @Binding var isShowing: Bool
    @StateObject private var networkManager = NetworkManager.shared
    @StateObject private var audioManager = AudioPlayerManager.shared
    @State private var isLoadingLyrics = false
    @State private var currentLyrics: LyricsResponse?
    @State private var parsedLines: [LyricLine] = []
    
    private var activeLineIndex: Int? {
        guard !parsedLines.isEmpty else { return nil }
        let progress = audioManager.progress
        for i in (0..<parsedLines.count).reversed() {
            if parsedLines[i].time <= progress {
                return i
            }
        }
        return 0
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.spiderDarkGrey.edgesIgnoringSafeArea(.all)
                
                if isLoadingLyrics {
                    VStack(spacing: 15) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.spiderNeonRed))
                            .scaleEffect(1.6)
                        Text("Fetching lyrics...")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                } else if let lyrics = currentLyrics, !lyrics.lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if lyrics.isSynced == true, !parsedLines.isEmpty {
                        ScrollViewReader { proxy in
                            ScrollView(showsIndicators: false) {
                                VStack(alignment: .leading, spacing: 20) {
                                    ForEach(Array(parsedLines.enumerated()), id: \.element.id) { index, line in
                                        Text(line.text)
                                            .font(.system(size: activeLineIndex == index ? 26 : 22, weight: .bold, design: .rounded))
                                            .foregroundColor(activeLineIndex == index ? .white : .gray.opacity(0.5))
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .id(index)
                                            .animation(.easeInOut(duration: 0.3), value: activeLineIndex)
                                    }
                                    
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.caption2)
                                            .foregroundColor(Theme.spiderNeonRed)
                                        Text("Source: \(lyrics.source)")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.top, 40)
                                    .padding(.bottom, 60)
                                }
                                .padding(.horizontal, 24)
                                .padding(.top, 40)
                            }
                            .onChange(of: activeLineIndex) { _, newIndex in
                                if let index = newIndex {
                                    withAnimation(.easeInOut(duration: 0.5)) {
                                        proxy.scrollTo(index, anchor: .center)
                                    }
                                }
                            }
                        }
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 16) {
                                Text(lyrics.lyrics)
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.leading)
                                    .padding(.horizontal, 24)
                                    .padding(.top, 20)
                                    .lineSpacing(14)
                                
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.caption2)
                                        .foregroundColor(Theme.spiderNeonRed)
                                    Text("Source: \(lyrics.source)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding(.top, 30)
                                .padding(.bottom, 60)
                            }
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "quote.bubble")
                            .font(.system(size: 44))
                            .foregroundColor(.gray.opacity(0.6))
                        Text("No lyrics found.")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        if let song = song {
                            Button(action: {
                                loadLyrics(for: song)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Retry")
                                }
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Theme.spiderNeonRed.opacity(0.8))
                                .cornerRadius(20)
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack {
                        Text("LYRICS")
                            .font(.caption)
                            .bold()
                            .foregroundColor(Theme.spiderNeonRed)
                        if let song = song {
                            Text(song.title)
                                .font(.headline)
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isShowing = false
                    }
                    .foregroundColor(Theme.spiderNeonRed)
                }
            }
        }
        .onAppear {
            if let song = song {
                loadLyrics(for: song)
            }
        }
        .onChange(of: song?.id) { _, _ in
            if let song = song {
                loadLyrics(for: song)
            }
        }
    }
    
    private func loadLyrics(for song: Song) {
        isLoadingLyrics = true
        networkManager.fetchLyrics(videoId: song.id) { lyrics in
            self.currentLyrics = lyrics
            if let lyrics = lyrics, lyrics.isSynced == true {
                self.parsedLines = self.parseLRC(lyrics.lyrics)
            } else {
                self.parsedLines = []
            }
            self.isLoadingLyrics = false
        }
    }
    
    private func parseLRC(_ lrc: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        let rawLines = lrc.components(separatedBy: .newlines)
        
        let regex = try? NSRegularExpression(pattern: "\\[(\\d{2}):(\\d{2})\\.(\\d{2,3})\\](.*)")
        
        for rawLine in rawLines {
            guard let match = regex?.firstMatch(in: rawLine, options: [], range: NSRange(location: 0, length: rawLine.utf16.count)) else { continue }
            
            if let minRange = Range(match.range(at: 1), in: rawLine),
               let secRange = Range(match.range(at: 2), in: rawLine),
               let milRange = Range(match.range(at: 3), in: rawLine),
               let textRange = Range(match.range(at: 4), in: rawLine) {
                
                let min = Double(rawLine[minRange]) ?? 0
                let sec = Double(rawLine[secRange]) ?? 0
                let milString = rawLine[milRange]
                let mil = Double(milString) ?? 0
                
                let time = (min * 60) + sec + (mil / (milString.count == 3 ? 1000.0 : 100.0))
                let text = String(rawLine[textRange]).trimmingCharacters(in: .whitespaces)
                
                if !text.isEmpty {
                    lines.append(LyricLine(time: time, text: text))
                }
            }
        }
        return lines
    }
}
