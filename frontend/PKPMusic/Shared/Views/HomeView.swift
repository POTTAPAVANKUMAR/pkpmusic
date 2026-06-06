import SwiftUI

struct HomeView: View {
    @StateObject private var networkManager = NetworkManager.shared
    @StateObject private var audioManager = AudioPlayerManager.shared
    @State private var searchText = ""
    @State private var showFullScreenPlayer = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    let queue = !searchText.isEmpty ? networkManager.searchResults : networkManager.songs
                    
                    if !searchText.isEmpty {
                        Text("Search Results")
                            .font(.title2)
                            .bold()
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(networkManager.searchResults.indices, id: \.self) { index in
                                let song = networkManager.searchResults[index]
                                SongCardView(song: song)
                                    .onTapGesture {
                                        audioManager.play(song: song, in: networkManager.searchResults, at: index)
                                        showFullScreenPlayer = true
                                    }
                            }
                        }
                        .padding(.horizontal)
                        
                    } else {
                        Text("Recently Played")
                            .font(.title2)
                            .bold()
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(networkManager.songs.indices, id: \.self) { index in
                                    let song = networkManager.songs[index]
                                    SongCardView(song: song)
                                        .onTapGesture {
                                            audioManager.play(song: song, in: networkManager.songs, at: index)
                                            showFullScreenPlayer = true
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Listen Now")
            .searchable(text: $searchText, prompt: "Search YouTube Music")
            .onChange(of: searchText) { newValue in
                if newValue.count > 2 {
                    networkManager.searchYouTube(query: newValue)
                } else if newValue.isEmpty {
                    networkManager.searchResults.removeAll()
                }
            }
            .onAppear {
                networkManager.fetchSongs()
            }
        }
    }
}

struct SongCardView: View {
    let song: Song
    
    var body: some View {
        VStack(alignment: .leading) {
            if let coverUrl = song.coverArtUrl, let url = URL(string: coverUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 150, height: 150)
                .cornerRadius(12)
                .shadow(radius: 5)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(gradient: Gradient(colors: [.purple, .pink]), startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 150, height: 150)
                    .shadow(radius: 5)
            }
            
            Text(song.title)
                .font(.headline)
                .lineLimit(1)
            
            Text(song.artist)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(width: 150)
    }
}
