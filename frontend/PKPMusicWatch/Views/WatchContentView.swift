import SwiftUI

struct WatchContentView: View {
    @EnvironmentObject var audioManager: AudioPlayerManager
    
    var body: some View {
        TabView {
            WatchPlayerView()
                .tabItem {
                    Label("Now Playing", systemImage: "play.circle.fill")
                }
            
            NavigationView {
                List {
                    Text("Favorites")
                    Text("Offline Music")
                }
                .navigationTitle("Library")
            }
            .tabItem {
                Label("Library", systemImage: "music.note.list")
            }
        }
    }
}
