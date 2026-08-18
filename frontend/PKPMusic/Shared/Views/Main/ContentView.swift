import SwiftUI

struct ContentView: View {
    @StateObject private var audioManager = AudioPlayerManager.shared
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    
    init() {
        ThemeManager.shared.updateTabBarAppearance()
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
                            
                            HistoryView()
                                .tabItem {
                                    Label("History", systemImage: "clock.arrow.circlepath")
                                }
                            
                            ChatListView()
                                .tabItem {
                                    Label("Chat", systemImage: "message.fill")
                                }
                                
                            DownloadsView()
                                .tabItem {
                                    Label("Offline", systemImage: "arrow.down.circle.fill")
                                }
                            
                            WebView(urlString: "https://pkpmusic.pottapk.win/docs")
                                .edgesIgnoringSafeArea(.top)
                                .tabItem {
                                    Label("API", systemImage: "network")
                                }
                            
                            WebView(urlString: "https://postgresql.pottapk.win/")
                                .edgesIgnoringSafeArea(.top)
                                .tabItem {
                                    Label("DB", systemImage: "cylinder.split.1x2")
                                }
                                
                            WebView(urlString: "https://pkpmusiclogs.pottapk.win/")
                                .edgesIgnoringSafeArea(.top)
                                .tabItem {
                                    Label("Logs", systemImage: "terminal.fill")
                                }
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
    }
}
