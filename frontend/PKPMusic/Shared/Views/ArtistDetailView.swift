import SwiftUI

struct ArtistDetailView: View {
    let artistId: String
    let artistName: String
    
    @StateObject private var networkManager = NetworkManager.shared
    @StateObject private var audioManager = AudioPlayerManager.shared
    
    @State private var artistDetail: ArtistDetail?
    @State private var isLoading = true
    @State private var showFullScreenPlayer = false
    
    var body: some View {
        ZStack {
            Theme.SpiderBackground()
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.spiderNeonRed))
                    .scaleEffect(1.5)
            } else if let detail = artistDetail {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        ZStack(alignment: .bottomLeading) {
                            if let headerUrl = detail.thumbnails.last?.url, let url = URL(string: headerUrl) {
                                AsyncImage(url: url) { image in
                                    image.resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Rectangle().fill(Theme.spiderDarkGrey)
                                }
                                .frame(height: 250)
                                .clipped()
                            } else {
                                Rectangle().fill(Theme.spiderDarkGrey)
                                    .frame(height: 250)
                            }
                            
                            LinearGradient(gradient: Gradient(colors: [.clear, .black.opacity(0.9)]), startPoint: .top, endPoint: .bottom)
                                .frame(height: 250)
                            
                            VStack(alignment: .leading) {
                                Text(detail.name)
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(.white)
                                
                                if let subs = detail.subscribers {
                                    Text("\(subs) subscribers")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding()
                        }
                        
                        // Top Songs
                        if !detail.songs.isEmpty {
                            VStack(alignment: .leading) {
                                Text("Top Songs")
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(.white)
                                    .padding(.horizontal)
                                
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
                                .padding(.horizontal)
                            }
                        }
                    }
                }
            } else {
                Text("Failed to load artist.")
                    .foregroundColor(.gray)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            networkManager.fetchArtist(channelId: artistId) { detail in
                self.artistDetail = detail
                self.isLoading = false
            }
        }
        .fullScreenCover(isPresented: $showFullScreenPlayer) {
            FullScreenPlayerView(isShowing: $showFullScreenPlayer)
        }
    }
}
