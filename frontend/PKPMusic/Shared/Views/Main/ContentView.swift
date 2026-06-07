import SwiftUI

struct ContentView: View {
    @StateObject private var audioManager = AudioPlayerManager.shared
    @StateObject private var authManager = AuthManager.shared
    
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
        Group {
            ZStack {
                if authManager.isAuthenticated {
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
                            
                            ChatListView()
                                .tabItem {
                                    Label("Chat", systemImage: "message.fill")
                                }
                            
                            WebView(urlString: "https://pkpmusic.pottapk.win/docs")
                                .edgesIgnoringSafeArea(.top)
                                .tabItem {
                                    Label("API", systemImage: "network")
                                }
                            
                            WebView(urlString: "https://pgadmin.pottapk.win")
                                .edgesIgnoringSafeArea(.top)
                                .tabItem {
                                    Label("DB", systemImage: "cylinder.split.1x2")
                                }
                        }
                        .accentColor(Theme.spiderRed)
                        
                        if audioManager.isPlaying || audioManager.currentSong != nil {
                            MiniPlayerView()
                        }
                    }
                } else {
                    LoginView()
                }
                
                // Spiderman Easter Egg overlaying the entire app
                Theme.SwingingMilesView()
            }
        }
        .preferredColorScheme(.dark)
    }
}
