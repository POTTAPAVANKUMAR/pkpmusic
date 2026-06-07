import SwiftUI

struct FullScreenPlayerView: View {
    @StateObject private var audioManager = AudioPlayerManager.shared
    @StateObject private var networkManager = NetworkManager.shared
    @Binding var isShowing: Bool
    
    @State private var showingOptions = false
    @State private var showingPlaylists = false
    
    @State private var showingLyrics = false
    @State private var isLoadingLyrics = false
    @State private var currentLyrics: LyricsResponse?
    
    var body: some View {
        ZStack {
            Theme.SpiderBackground()
            
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
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.spiderRed)
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
                        Button("Add to Playlist") {
                            networkManager.fetchPlaylists()
                            showingPlaylists = true
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                }
                .padding()
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
                        Rectangle().fill(Theme.spiderDarkGrey)
                    }
                    .frame(width: UIScreen.main.bounds.width - 60, height: UIScreen.main.bounds.width - 60)
                    .cornerRadius(20)
                    .shadow(color: Theme.spiderNeonRed.opacity(0.6), radius: 30, x: 0, y: 10)
                    .padding(.bottom, 40)
                    
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
                            if !showingLyrics {
                                showingLyrics = true
                                isLoadingLyrics = true
                                networkManager.fetchLyrics(videoId: song.id) { lyrics in
                                    self.currentLyrics = lyrics
                                    self.isLoadingLyrics = false
                                }
                            }
                        }) {
                            Image(systemName: "quote.bubble")
                                .font(.title)
                                .foregroundColor(Theme.spiderDarkGrey)
                        }
                        
                        Button(action: {
                            audioManager.isAutoPlayEnabled.toggle()
                        }) {
                            Image(systemName: "infinity")
                                .font(.title)
                                .foregroundColor(audioManager.isAutoPlayEnabled ? Theme.spiderNeonRed : .gray)
                        }
                        
                        Button(action: {
                            networkManager.addToFavorites(songId: song.id)
                        }) {
                            Image(systemName: networkManager.favorites.contains(where: { $0.id == song.id }) ? "heart.fill" : "heart")
                                .font(.title)
                                .foregroundColor(Theme.spiderNeonRed)
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    // Scrubber
                    VStack(spacing: 5) {
                        Slider(value: Binding(get: {
                            audioManager.progress
                        }, set: { newValue in
                            audioManager.seek(to: newValue)
                        }), in: 0...(audioManager.duration > 0 ? audioManager.duration : 1))
                        .accentColor(Theme.spiderNeonRed)
                        
                        HStack {
                            Text(formatTime(audioManager.progress))
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                            Text(formatTime(audioManager.duration))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 20)
                    
                    // Playback Controls
                    HStack(spacing: 30) {
                        // Shuffle Button
                        Button(action: {
                            audioManager.toggleShuffle()
                        }) {
                            Image(systemName: audioManager.isShuffled ? "shuffle" : "shuffle")
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
                            Image(systemName: audioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 70))
                                .foregroundColor(Theme.spiderNeonRed)
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
            
            // Lyrics Overlay
            if showingLyrics {
                ZStack {
                    Theme.SpiderBackground()
                        .opacity(0.95)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                showingLyrics = false
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .padding()
                            }
                        }
                        
                        if isLoadingLyrics {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Theme.spiderNeonRed))
                                .scaleEffect(1.5)
                            Spacer()
                        } else if let lyrics = currentLyrics {
                            ScrollView {
                                Text(lyrics.lyrics)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding()
                                    .lineSpacing(10)
                                
                                Text("Source: \(lyrics.source)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.top, 20)
                                    .padding(.bottom, 40)
                            }
                        } else {
                            Spacer()
                            Text("No lyrics found for this song.")
                                .foregroundColor(.gray)
                            Spacer()
                        }
                    }
                }
                .transition(.move(edge: .bottom))
                .zIndex(2)
            }
        }
        // Allow swiping down to dismiss
        .gesture(DragGesture().onEnded { value in
            if value.translation.height > 100 && !showingLyrics {
                isShowing = false
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
