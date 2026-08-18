import SwiftUI

struct ArtistAlbumsView: View {
    let artistId: String
    let artistName: String
    
    @StateObject private var networkManager = NetworkManager.shared
    @State private var albums: [AlbumRef]?
    @State private var isLoading = true
    
    // We would normally support pagination via params
    
    var body: some View {
        ZStack {
            ThemeManager.shared.currentTheme.backgroundColor.edgesIgnoringSafeArea(.all)
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
            } else if let albums = albums, !albums.isEmpty {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                        ForEach(albums, id: \.browseId) { album in
                            NavigationLink(destination: AlbumDetailView(albumId: album.browseId)) {
                                VStack {
                                    if let urlString = album.thumbnails?.last?.url, let url = URL(string: urlString) {
                                        AsyncImage(url: url) { image in
                                            image.resizable().aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Color.gray
                                        }
                                        .frame(width: 150, height: 150)
                                        .cornerRadius(12)
                                    } else {
                                        Color.gray
                                            .frame(width: 150, height: 150)
                                            .cornerRadius(12)
                                    }
                                    
                                    Text(album.title)
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                    }
                    .padding()
                }
            } else {
                Text("No albums found.")
                    .foregroundColor(.gray)
            }
        }
        .navigationTitle("\(artistName) Albums")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if isLoading {
                networkManager.fetchArtistAlbums(channelId: artistId, params: "") { result in
                    self.albums = result
                    self.isLoading = false
                }
            }
        }
    }
}
