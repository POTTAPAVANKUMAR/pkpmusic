import SwiftUI

struct HomeView: View {
    @StateObject private var networkManager = NetworkManager.shared
    @StateObject private var audioManager = AudioPlayerManager.shared
    
    @State private var searchText = ""
    @State private var showFullScreenPlayer = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.SpiderBackground()
                
                VStack(spacing: 0) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search YouTube Music", text: $searchText, onCommit: {
                            networkManager.searchYouTube(query: searchText)
                        })
                        .accentColor(Theme.spiderNeonRed)
                        .foregroundColor(.white)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(15)
                    .padding()
                    
                    if networkManager.isLoading {
                        Spacer()
                        ProgressView("Web-slinging data...")
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.spiderNeonRed))
                            .foregroundColor(Theme.spiderRed)
                        Spacer()
                    } else if networkManager.searchResults.isEmpty {
                        Spacer()
                        VStack(spacing: 15) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 60))
                                .foregroundColor(Theme.spiderRed)
                            Text("Find Your Soundtrack")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text("Search for any song on YouTube Music")
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(networkManager.searchResults.indices, id: \.self) { index in
                                    let song = networkManager.searchResults[index]
                                    HStack {
                                        AsyncImage(url: URL(string: song.coverArtUrl ?? "")) { image in
                                            image.resizable().aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Color.gray.opacity(0.3)
                                        }
                                        .frame(width: 60, height: 60)
                                        .cornerRadius(8)
                                        .shadow(color: Theme.spiderNeonRed.opacity(0.3), radius: 5, x: 0, y: 0)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(song.title)
                                                .font(.headline)
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                            Text(song.artist)
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        
                                        if audioManager.currentSong?.id == song.id {
                                            Image(systemName: "waveform")
                                                .foregroundColor(Theme.spiderNeonRed)
                                        }
                                    }
                                    .padding(10)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Theme.spiderDarkGrey, lineWidth: 1)
                                    )
                                    .padding(.horizontal)
                                    .onTapGesture {
                                        audioManager.play(song: song, in: networkManager.searchResults, at: index)
                                        showFullScreenPlayer = true
                                    }
                                }
                            }
                            .padding(.vertical)
                        }
                    }
                }
            }
            .navigationTitle("Listen Now")
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
