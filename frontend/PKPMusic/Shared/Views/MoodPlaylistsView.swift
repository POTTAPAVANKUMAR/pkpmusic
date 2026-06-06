import SwiftUI

struct MoodPlaylistsView: View {
    let params: String
    let moodTitle: String
    
    @StateObject private var networkManager = NetworkManager.shared
    @State private var playlists: [DashboardItem] = []
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            Theme.SpiderBackground()
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.spiderNeonRed))
                    .scaleEffect(1.5)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                        ForEach(playlists, id: \.id) { playlist in
                            NavigationLink(destination: AlbumDetailView(albumId: playlist.id)) { // We can use AlbumDetailView for playlists too since it just fetches a browseId/playlistId
                                DashboardItemCard(item: playlist)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(moodTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            networkManager.fetchMoodPlaylists(params: params) { items in
                self.playlists = items
                self.isLoading = false
            }
        }
    }
}
