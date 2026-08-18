import SwiftUI

struct YTUserProfileView: View {
    let channelId: String
    
    @StateObject private var networkManager = NetworkManager.shared
    @State private var profile: YTUserProfile?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            ThemeManager.shared.currentTheme.backgroundColor.edgesIgnoringSafeArea(.all)
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
            } else if let profile = profile {
                ScrollView {
                    VStack(spacing: 20) {
                        if let urlString = profile.thumbnails?.last?.url, let url = URL(string: urlString) {
                            AsyncImage(url: url) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle().fill(Color.gray)
                            }
                            .frame(width: 150, height: 150)
                            .clipShape(Circle())
                            .padding(.top)
                        }
                        
                        Text(profile.name ?? "Unknown User")
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(.white)
                        
                        // We could fetch and display playlists/videos here via additional API calls.
                        Text("User profile loaded. Playlists and videos can be fetched using the corresponding endpoints.")
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .padding()
                }
            } else {
                Text("Failed to load profile.")
                    .foregroundColor(.gray)
            }
        }
        .navigationTitle(profile?.name ?? "Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if isLoading {
                networkManager.fetchYTUserProfile(channelId: channelId) { data in
                    self.profile = data
                    self.isLoading = false
                }
            }
        }
    }
}
