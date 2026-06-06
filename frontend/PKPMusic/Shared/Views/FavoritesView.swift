import SwiftUI

struct FavoritesView: View {
    @StateObject private var networkManager = NetworkManager.shared
    @StateObject private var audioManager = AudioPlayerManager.shared
    @State private var showFullScreenPlayer = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.SpiderBackground()
                
                VStack {
                    if networkManager.favorites.isEmpty {
                        Spacer()
                        VStack(spacing: 20) {
                            Image(systemName: "heart.slash")
                                .font(.system(size: 60))
                                .foregroundColor(Theme.spiderRed)
                            Text("No Favorites Yet")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text("Your favorited tracks will appear here")
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(networkManager.favorites.indices, id: \.self) { index in
                                    let song = networkManager.favorites[index]
                                    HStack {
                                        AsyncImage(url: URL(string: song.cover_art_url ?? "")) { image in
                                            image.resizable().aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Color.gray.opacity(0.3)
                                        }
                                        .frame(width: 60, height: 60)
                                        .cornerRadius(8)
                                        .shadow(color: Theme.spiderNeonRed.opacity(0.3), radius: 5, x: 0, y: 0)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(song.title)
                                                .font(.headline)
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                            Text(song.artist)
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        
                                        Image(systemName: "heart.fill")
                                            .foregroundColor(Theme.spiderNeonRed)
                                    }
                                    .padding(10)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Theme.spiderDarkGrey, lineWidth: 1)
                                    )
                                    .padding(.horizontal)
                                    .onTapGesture {
                                        audioManager.play(song: song, in: networkManager.favorites, at: index)
                                        showFullScreenPlayer = true
                                    }
                                }
                            }
                            .padding(.vertical)
                        }
                    }
                }
            }
            .navigationTitle("Favorites")
            .navigationBarHidden(true)
            .onAppear {
                networkManager.fetchFavorites()
            }
            .fullScreenCover(isPresented: $showFullScreenPlayer) {
                FullScreenPlayerView(isShowing: $showFullScreenPlayer)
            }
        }
    }
}
