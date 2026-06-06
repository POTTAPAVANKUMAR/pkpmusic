import SwiftUI

struct ContentView: View {
    @StateObject private var audioManager = AudioPlayerManager.shared
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                HomeView()
                    .tabItem {
                        Label("Listen Now", systemImage: "play.circle.fill")
                    }
                
                FavoritesView()
                    .tabItem {
                        Label("Favorites", systemImage: "heart.fill")
                    }
                
                PlaylistsView()
                    .tabItem {
                        Label("Playlists", systemImage: "music.note.list")
                    }
            }
            
            if audioManager.isPlaying || audioManager.currentSong != nil {
                MiniPlayerView()
                    .padding(.bottom, 50) // Adjust for TabBar height
            }
        }
    }
}
