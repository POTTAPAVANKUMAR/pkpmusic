import SwiftUI

struct RelatedSongsView: View {
    let videoId: String
    
    @StateObject private var networkManager = NetworkManager.shared
    @StateObject private var audioManager = AudioPlayerManager.shared
    
    @State private var relatedSongs: [Song] = []
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            ThemeManager.shared.currentTheme.backgroundColor.edgesIgnoringSafeArea(.all)
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
            } else if !relatedSongs.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(relatedSongs.indices, id: \.self) { index in
                            let song = relatedSongs[index]
                            SongRowView(song: song, isPlaying: audioManager.currentSong?.id == song.id)
                                .onTapGesture {
                                    audioManager.play(song: song, in: relatedSongs, at: index)
                                }
                        }
                    }
                    .padding()
                }
            } else {
                Text("No related songs found.")
                    .foregroundColor(.gray)
            }
        }
        .navigationTitle("Up Next")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if isLoading {
                networkManager.fetchSongRelated(videoId: videoId) { data in
                    self.relatedSongs = data?.related ?? []
                    self.isLoading = false
                }
            }
        }
    }
}
