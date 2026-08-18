import SwiftUI

struct PodcastChannelView: View {
    let channelId: String
    
    @StateObject private var networkManager = NetworkManager.shared
    @State private var channel: PodcastChannel?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            ThemeManager.shared.currentTheme.backgroundColor.edgesIgnoringSafeArea(.all)
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
            } else if let channel = channel {
                ScrollView {
                    VStack(spacing: 20) {
                        if let urlString = channel.thumbnails?.last?.url, let url = URL(string: urlString) {
                            AsyncImage(url: url) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Color.gray
                            }
                            .frame(width: 200, height: 200)
                            .cornerRadius(20)
                            .padding(.top)
                        }
                        
                        Text(channel.title ?? "Unknown Podcast Channel")
                            .font(.title)
                            .bold()
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        if let desc = channel.description {
                            Text(desc)
                                .foregroundColor(.gray)
                                .padding()
                        }
                    }
                    .padding()
                }
            } else {
                Text("Failed to load podcast channel.")
                    .foregroundColor(.gray)
            }
        }
        .navigationTitle("Podcast Channel")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if isLoading {
                networkManager.fetchPodcastChannel(channelId: channelId) { data in
                    self.channel = data
                    self.isLoading = false
                }
            }
        }
    }
}
