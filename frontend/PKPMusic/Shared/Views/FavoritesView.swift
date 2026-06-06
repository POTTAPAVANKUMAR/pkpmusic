import SwiftUI

struct FavoritesView: View {
    @StateObject private var networkManager = NetworkManager.shared
    @StateObject private var audioManager = AudioPlayerManager.shared
    @State private var showFullScreenPlayer = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if networkManager.favorites.isEmpty {
                        Text("No favorites yet. Add some by tapping the heart icon in the player!")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(Array(networkManager.favorites.enumerated()), id: \.element.id) { index, song in
                                SongCardView(song: song)
                                    .onTapGesture {
                                        audioManager.play(song: song, in: networkManager.favorites, at: index)
                                        showFullScreenPlayer = true
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Favorites")
            .onAppear {
                networkManager.fetchFavorites()
            }
            .fullScreenCover(isPresented: $showFullScreenPlayer) {
                FullScreenPlayerView(isShowing: $showFullScreenPlayer)
            }
        }
    }
}
