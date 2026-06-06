import SwiftUI

struct ContentView: View {
    @StateObject private var audioManager = AudioPlayerManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Image(systemName: "play.circle.fill")
                        Text("Listen Now")
                    }
                    .tag(0)
                
                LibraryView()
                    .tabItem {
                        Image(systemName: "square.stack.fill")
                        Text("Library")
                    }
                    .tag(1)
                
                SearchView()
                    .tabItem {
                        Image(systemName: "magnifyingglass")
                        Text("Search")
                    }
                    .tag(2)
            }
            .accentColor(.pink) // Apple Music signature color
            
            // Glassmorphic MiniPlayer sitting above the tab bar
            if audioManager.currentSong != nil {
                MiniPlayerView()
                    .padding(.bottom, 49) // Offset for standard TabBar height
            }
        }
    }
}
