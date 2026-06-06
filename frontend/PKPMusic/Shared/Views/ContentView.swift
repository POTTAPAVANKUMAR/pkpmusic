import SwiftUI

struct ContentView: View {
    @StateObject private var audioManager = AudioPlayerManager.shared
    
    init() {
        // Customize the TabBar appearance for the Spiderman theme
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Theme.spiderBlack)
        
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = UIColor.white.withAlphaComponent(0.5)
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white.withAlphaComponent(0.5)]
        
        itemAppearance.selected.iconColor = UIColor(Theme.spiderRed)
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(Theme.spiderRed)]
        
        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance
        
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "music.note.house.fill")
                    }
                
                LibraryView()
                    .tabItem {
                        Label("Library", systemImage: "play.square.stack.fill")
                    }
            }
            .accentColor(Theme.spiderRed)
            
            if audioManager.isPlaying || audioManager.currentSong != nil {
                MiniPlayerView()
                    .padding(.bottom, 50) // Adjust for TabBar height
            }
        }
        .preferredColorScheme(.dark)
    }
}
