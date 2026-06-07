import SwiftUI

@main
struct PKPMusicWatchApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var audioManager = AudioPlayerManager.shared
    
    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                WatchContentView()
                    .environmentObject(authManager)
                    .environmentObject(audioManager)
            } else {
                Text("Please log in on your iPhone first.")
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
    }
}
