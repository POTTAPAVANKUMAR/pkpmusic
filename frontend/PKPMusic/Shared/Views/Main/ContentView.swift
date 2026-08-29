import SwiftUI

struct ContentView: View {
    @StateObject private var audioManager = AudioPlayerManager.shared
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var selectedTab: Int = 0
    
    init() {
        ThemeManager.shared.updateTabBarAppearance()
    }
    
    var body: some View {
        Group {
            ZStack {
                if authManager.isAuthenticated {
                    ZStack(alignment: .bottom) {
                        TabView(selection: $selectedTab) {
                            HomeView()
                                .tabItem {
                                    Label("Home", systemImage: "music.note.house.fill")
                                }
                                .tag(0)
                                
                            ExploreView()
                                .tabItem {
                                    Label("Explore", systemImage: "safari.fill")
                                }
                                .tag(1)
                            
                            LibraryView()
                                .tabItem {
                                    Label("Library", systemImage: "play.square.stack.fill")
                                }
                                .tag(2)
                            
                            HistoryView()
                                .tabItem {
                                    Label("History", systemImage: "clock.arrow.circlepath")
                                }
                                .tag(3)
                            
                            ChatListView()
                                .tabItem {
                                    Label("Chat", systemImage: "message.fill")
                                }
                                .tag(4)
                                
                            DownloadsView()
                                .tabItem {
                                    Label("Offline", systemImage: "arrow.down.circle.fill")
                                }
                                .tag(5)
                            
                            ServerHubView()
                                .tabItem {
                                    Label("Server", systemImage: "server.rack")
                                }
                                .tag(6)
                            
                            WebView(urlString: "https://pkpmusic.pottapk.win/docs")
                                .edgesIgnoringSafeArea(.top)
                                .tabItem {
                                    Label("API", systemImage: "network")
                                }
                                .tag(7)
                            
                            WebView(urlString: "https://postgresql.pottapk.win/")
                                .edgesIgnoringSafeArea(.top)
                                .tabItem {
                                    Label("DB", systemImage: "cylinder.split.1x2")
                                }
                                .tag(8)
                                
                            WebView(urlString: "https://pkpmusiclogs.pottapk.win/")
                                .edgesIgnoringSafeArea(.top)
                                .tabItem {
                                    Label("Logs", systemImage: "terminal.fill")
                                }
                                .tag(9)
                        }
                        .accentColor(themeManager.currentTheme.primaryColor)
                        
                        if audioManager.isPlaying || audioManager.currentSong != nil {
                            MiniPlayerView()
                        }
                    }
                } else {
                    LoginView()
                }
                
                // Dynamic Hero Easter Egg (Spider-Man, Batman, Iron Man)
                Theme.DynamicHeroView()
            }
        }
        .preferredColorScheme(.dark)
        .onOpenURL { url in
            handleDeepLink(url: url)
        }
    }
    
    private func handleDeepLink(url: URL) {
        guard let host = url.host?.lowercased() else { return }
        switch host {
        case "home":
            selectedTab = 0
        case "explore", "search":
            selectedTab = 1
        case "library":
            selectedTab = 2
        case "history":
            selectedTab = 3
        case "chat":
            selectedTab = 4
        case "offline", "downloads":
            selectedTab = 5
        case "server":
            selectedTab = 6
        case "play":
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let songId = components.queryItems?.first(where: { $0.name == "id" })?.value {
                audioManager.playSong(songId: songId)
            }
        default:
            break
        }
    }
}
