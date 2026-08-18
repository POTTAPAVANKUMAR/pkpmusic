import SwiftUI

struct FullScreenPlayerView: View {
    @StateObject private var audioManager = AudioPlayerManager.shared
    @StateObject private var networkManager = NetworkManager.shared
    @Binding var isShowing: Bool
    
    @State private var showingOptions = false
    @State private var showingPlaylists = false
    @State private var showingAlbum = false
    
    @State private var showingLyrics = false
    @State private var showingQueue = false
    
    var body: some View {
        ZStack {
            // Sleek Blurred Background
            if let song = audioManager.currentSong {
                AsyncImage(url: URL(string: song.coverArtUrl ?? "")) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Theme.SpiderBackground()
                }
                .frame(width: (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.width ?? 400, height: (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.height ?? 800)
                .clipped()
                .overlay(.ultraThinMaterial)
                .opacity(0.8) // Darken it slightly so text pops
                .ignoresSafeArea()
                
                Color.black.opacity(0.3).ignoresSafeArea() // Extra contrast
            } else {
                Theme.SpiderBackground().ignoresSafeArea()
            }
            
            VStack {
                // Header
                HStack {
                    Button(action: {
                        isShowing = false
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    Spacer()
                        Text("NOW PLAYING")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                            .tracking(2)
                    Spacer()
                    Button(action: {
                        showingOptions = true
                    }) {
                        Image(systemName: "ellipsis")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .confirmationDialog("Options", isPresented: $showingOptions, titleVisibility: .visible) {
                        if let song = audioManager.currentSong {
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
                                Button("Go to Album") {
                                    showingAlbum = true
                                }
                            }
                            
                            Button("Play Radio (Similar Songs)") {
                                networkManager.fetchUpNext(videoId: song.id) { recommendedSongs in
                                    if let first = recommendedSongs.first {
                                        audioManager.play(song: first, in: recommendedSongs, at: 0)
                                    }
                                }
                            }
                        }
                        Button("Add to Playlist") {
                            networkManager.fetchPlaylists()
                            showingPlaylists = true
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                }
                .padding(.horizontal)
                .padding(.top, 60)
                .padding(.bottom, 10)
                .sheet(isPresented: $showingAlbum) {
                    if let song = audioManager.currentSong, let albumId = song.albumId {
                        NavigationView {
                            AlbumDetailView(albumId: albumId)
                                .navigationBarItems(leading: Button("Close") {
                                    showingAlbum = false
                                })
                        }
                    }
                }
                .sheet(isPresented: $showingPlaylists) {
                    NavigationView {
                        List {
                            if networkManager.playlists.isEmpty {
                                Text("No playlists found. Create one in the Playlists tab!")
                                    .foregroundColor(.gray)
                            } else {
                                ForEach(networkManager.playlists, id: \.id) { playlist in
                                    Button(action: {
                                        if let song = audioManager.currentSong {
                                            networkManager.addSongToPlaylist(songId: song.id, playlistId: playlist.id)
                                        }
                                        showingPlaylists = false
                                    }) {
                                        Text(playlist.name)
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                        .navigationTitle("Select Playlist")
                        .navigationBarItems(trailing: Button("Cancel") {
                            showingPlaylists = false
                        })
                    }
                }
                
                Spacer()
                
                // Album Art with Spidey Glow
                if let song = audioManager.currentSong {
                    AsyncImage(url: URL(string: song.coverArtUrl ?? "")) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(Color.gray.opacity(0.2))
                    }
                    .frame(width: ((UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.width ?? 400) - 60, height: ((UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.width ?? 400) - 60)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 15)
                    .scaleEffect(audioManager.isPlaying ? 1.0 : 0.85) // Apple Music style bounce
                    .animation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0), value: audioManager.isPlaying)
                    .padding(.bottom, 30)
                    
                    // Song Info & Favorite
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(song.title)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Text(song.artist)
                                .font(.title3)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                        Spacer()
                        
                        Button(action: {
                            showingLyrics = true
                        }) {
                            Image(systemName: showingLyrics ? "quote.bubble.fill" : "quote.bubble")
                                .font(.title2)
                                .foregroundColor(showingLyrics ? Theme.spiderNeonRed : .white.opacity(0.85))
                                .padding(8)
                                .background(showingLyrics ? Theme.spiderNeonRed.opacity(0.2) : Color.white.opacity(0.12))
                                .clipShape(Circle())
                        }
                        
                        Button(action: {
                            showingQueue = true
                        }) {
                            Image(systemName: showingQueue ? "list.bullet.circle.fill" : "list.bullet")
                                .font(.title2)
                                .foregroundColor(showingQueue ? Theme.spiderNeonRed : .white.opacity(0.85))
                                .padding(8)
                                .background(showingQueue ? Theme.spiderNeonRed.opacity(0.2) : Color.white.opacity(0.12))
                                .clipShape(Circle())
                        }
                        
                        Button(action: {
                            audioManager.isAutoPlayEnabled.toggle()
                        }) {
                            Image(systemName: "infinity")
                                .font(.title2)
                                .foregroundColor(audioManager.isAutoPlayEnabled ? Theme.spiderNeonRed : .gray)
                                .padding(8)
                                .background(audioManager.isAutoPlayEnabled ? Theme.spiderNeonRed.opacity(0.2) : Color.white.opacity(0.12))
                                .clipShape(Circle())
                        }
                        
                        Button(action: {
                            networkManager.addToFavorites(songId: song.id)
                        }) {
                            Image(systemName: networkManager.favorites.contains(where: { $0.id == song.id }) ? "heart.fill" : "heart")
                                .font(.title2)
                                .foregroundColor(Theme.spiderNeonRed)
                                .padding(8)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    if let error = audioManager.playbackError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(Theme.spiderNeonRed)
                            .padding(.top, 4)
                            .transition(.opacity)
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
                    .padding(.top, 10)
                    
                    // Playback Controls
                    HStack(spacing: 30) {
                        // Shuffle Button
                        Button(action: {
                            audioManager.toggleShuffle()
                        }) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 24))
                                .foregroundColor(audioManager.isShuffled ? Theme.spiderNeonRed : .white.opacity(0.5))
                        }
                        
                        Button(action: {
                            audioManager.playPrevious()
                        }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 30))
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
                                    .font(.system(size: 75))
                                    .foregroundColor(.white)
                                    .opacity(audioManager.isLoading ? 0.35 : 1.0)
                                
                                if audioManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.spiderNeonRed))
                                        .scaleEffect(1.8)
                                }
                            }
                        }
                        
                        Button(action: {
                            audioManager.playNext()
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                        
                        // Repeat Button
                        Button(action: {
                            audioManager.toggleRepeat()
                        }) {
                            Image(systemName: audioManager.repeatMode == .one ? "repeat.1" : "repeat")
                                .font(.system(size: 24))
                                .foregroundColor(audioManager.repeatMode == .off ? .white.opacity(0.5) : Theme.spiderNeonRed)
                        }
                    }
                    .padding(.top, 30)
                    
                    Spacer()
                } else {
                    Text("No Song Playing")
                        .foregroundColor(.gray)
                    Spacer()
                }
        }
        }
        .sheet(isPresented: $showingLyrics) {
            LyricsView(song: audioManager.currentSong, isShowing: $showingLyrics)
        }
        .sheet(isPresented: $showingQueue) {
            QueueView(isShowing: $showingQueue)
        }
        // Allow swiping down to dismiss
        .gesture(DragGesture().onEnded { value in
            if value.translation.height > 100 {
                if showingLyrics {
                    withAnimation(.spring()) {
                        showingLyrics = false
                    }
                } else if showingQueue {
                    withAnimation(.spring()) {
                        showingQueue = false
                    }
                } else {
                    isShowing = false
                }
            }
        })
    }
    
    private func formatTime(_ time: Double) -> String {
        guard time.isFinite && !time.isNaN else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct LyricsView: View {
    let song: Song?
    @Binding var isShowing: Bool
    @StateObject private var networkManager = NetworkManager.shared
    @State private var isLoadingLyrics = false
    @State private var currentLyrics: LyricsResponse?
    
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
            self.isLoadingLyrics = false
        }
    }
}
