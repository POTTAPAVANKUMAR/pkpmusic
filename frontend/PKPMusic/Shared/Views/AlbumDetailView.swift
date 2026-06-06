import SwiftUI

struct AlbumDetailView: View {
    let albumId: String
    
    @StateObject private var networkManager = NetworkManager.shared
    @StateObject private var audioManager = AudioPlayerManager.shared
    
    @State private var albumDetail: AlbumDetail?
    @State private var isLoading = true
    @State private var showFullScreenPlayer = false
    
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
                            
                            if let desc = detail.description {
                                Text(desc)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            
                            Text("\(detail.trackCount) tracks")
                                .font(.caption)
                                .foregroundColor(Theme.spiderRed)
                        }
                        
                        // Songs
                        if !detail.songs.isEmpty {
                            LazyVStack(spacing: 12) {
                                ForEach(detail.songs.indices, id: \.self) { index in
                                    let song = detail.songs[index]
                                    SongRowView(song: song, isPlaying: audioManager.currentSong?.id == song.id)
                                        .onTapGesture {
                                            audioManager.play(song: song, in: detail.songs, at: index)
                                            showFullScreenPlayer = true
                                            networkManager.recordHistory(songId: song.id)
                                        }
                                }
                            }
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
