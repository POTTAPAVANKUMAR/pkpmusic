import SwiftUI

struct AlbumDetailView: View {
    let albumId: String
    
    @StateObject private var networkManager = NetworkManager.shared
    @StateObject private var audioManager = AudioPlayerManager.shared
    
    @State private var albumDetail: AlbumDetail?
    @State private var isLoading = true
    @State private var showFullScreenPlayer = false
    
    @State private var searchText = ""
    
    private var filteredSongs: [Song] {
        guard let detail = albumDetail else { return [] }
        if searchText.isEmpty { return detail.songs }
        return detail.songs.filter { song in
            song.title.localizedCaseInsensitiveContains(searchText) ||
            song.artist.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        ZStack {
            Theme.SpiderBackground()
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.spiderNeonRed))
                    .scaleEffect(1.5)
            } else if let detail = albumDetail {
                ScrollView {
                    VStack(alignment: .center, spacing: 20) {
                        // Header
                        if let headerUrl = detail.thumbnails.last?.url, let url = URL(string: headerUrl) {
                            AsyncImage(url: url) { image in
                                image.resizable()
                                    .aspectRatio(contentMode: .fit)
                            } placeholder: {
                                Rectangle().fill(Theme.spiderDarkGrey)
                            }
                            .frame(width: 250, height: 250)
                            .cornerRadius(15)
                            .shadow(color: Theme.spiderNeonRed.opacity(0.3), radius: 20)
                            .padding(.top, 20)
                        }
                        
                        VStack(spacing: 8) {
                            Text(detail.title)
                                .font(.title)
                                .bold()
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            if let desc = detail.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                    .lineLimit(3)
                            }
                            
                            Text("\(detail.trackCount) tracks")
                                .font(.caption)
                                .foregroundColor(Theme.spiderRed)
                        }
                        
                        // Action Buttons: Play & Shuffle
                        if !detail.songs.isEmpty {
                            HStack(spacing: 20) {
                                Button(action: {
                                    audioManager.isShuffled = false
                                    audioManager.play(song: detail.songs[0], in: detail.songs, at: 0)
                                    showFullScreenPlayer = true
                                }) {
                                    HStack {
                                        Image(systemName: "play.fill")
                                        Text("Play")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Theme.spiderNeonRed)
                                    .cornerRadius(25)
                                }
                                .buttonStyle(SpiderButtonStyle())
                                
                                Button(action: {
                                    audioManager.isShuffled = true
                                    let randomSong = detail.songs.randomElement() ?? detail.songs[0]
                                    audioManager.play(song: randomSong, in: detail.songs, at: 0)
                                    showFullScreenPlayer = true
                                }) {
                                    HStack {
                                        Image(systemName: "shuffle")
                                        Text("Shuffle")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Theme.spiderDarkGrey)
                                    .cornerRadius(25)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 25)
                                            .stroke(Theme.spiderNeonRed.opacity(0.5), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(SpiderButtonStyle())
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Search Bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            TextField("Search in album...", text: $searchText)
                                .foregroundColor(.white)
                                .disableAutocorrection(true)
                                .autocapitalization(.none)
                            
                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(12)
                        .background(Theme.spiderDarkGrey.opacity(0.6))
                        .cornerRadius(10)
                        .padding(.horizontal)
                        
                        // Songs
                        if !filteredSongs.isEmpty {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredSongs.indices, id: \.self) { index in
                                    let song = filteredSongs[index]
                                    SongRowView(song: song, isPlaying: audioManager.currentSong?.id == song.id)
                                        .onTapGesture {
                                            // Make sure we pass the full album context or just the filtered list?
                                            // Usually better to play the filtered list if searching
                                            audioManager.play(song: song, in: filteredSongs, at: index)
                                            showFullScreenPlayer = true
                                            networkManager.recordHistory(songId: song.id)
                                        }
                                }
                            }
                            .padding()
                        } else if !detail.songs.isEmpty {
                            Text("No songs match your search.")
                                .foregroundColor(.gray)
                                .padding()
                        }
                    }
                }
            } else {
                Text("Failed to load album.")
                    .foregroundColor(.gray)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            networkManager.fetchAlbum(browseId: albumId) { detail in
                self.albumDetail = detail
                self.isLoading = false
            }
        }
        .fullScreenCover(isPresented: $showFullScreenPlayer) {
            FullScreenPlayerView(isShowing: $showFullScreenPlayer)
        }
    }
}
