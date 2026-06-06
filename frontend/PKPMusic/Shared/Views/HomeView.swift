import SwiftUI

struct HomeView: View {
    @StateObject private var networkManager = NetworkManager.shared
    @StateObject private var audioManager = AudioPlayerManager.shared
    
    @State private var searchQuery = ""
    @State private var isSearching = false
    @State private var showFullScreenPlayer = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.SpiderBackground()
                
                VStack(spacing: 0) {
                    // Header & Search
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Discover")
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(.white)
                        
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            TextField("Search songs, artists...", text: $searchQuery, onCommit: {
                                if !searchQuery.isEmpty {
                                    isSearching = true
                                    networkManager.searchYouTube(query: searchQuery)
                                }
                            })
                            .foregroundColor(.white)
                            .accentColor(Theme.spiderNeonRed)
                            
                            if !searchQuery.isEmpty {
                                Button(action: {
                                    searchQuery = ""
                                    isSearching = false
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(15)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Theme.spiderDarkGrey, lineWidth: 1)
                        )
                    }
                    .padding()
                    
                    if isSearching {
                        // Search Results List
                        if networkManager.isLoading {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Theme.spiderNeonRed))
                                .scaleEffect(1.5)
                            Spacer()
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(networkManager.searchResults.indices, id: \.self) { index in
                                        let song = networkManager.searchResults[index]
                                        SongRowView(song: song, isPlaying: audioManager.currentSong?.id == song.id)
                                            .onTapGesture {
                                                audioManager.play(song: song, in: networkManager.searchResults, at: index)
                                                showFullScreenPlayer = true
                                                networkManager.recordHistory(songId: song.id)
                                            }
                                    }
                                }
                                .padding()
                            }
                        }
                    } else {
                        // Dashboard View
                        if networkManager.dashboardSections.isEmpty {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Theme.spiderNeonRed))
                                .scaleEffect(1.5)
                            Spacer()
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 25, alignment: .leading) {
                                    ForEach(networkManager.dashboardSections, id: \.title) { section in
                                        VStack(alignment: .leading, spacing: 15) {
                                            Text(section.title)
                                                .font(.title2)
                                                .bold()
                                                .foregroundColor(.white)
                                                .padding(.horizontal)
                                            
                                            ScrollView(.horizontal, showsIndicators: false) {
                                                LazyHStack(spacing: 15) {
                                                    ForEach(section.items, id: \.id) { item in
                                                        DashboardCardView(item: item)
                                                            .onTapGesture {
                                                                if item.type == "song" {
                                                                    // Play the song
                                                                    let song = Song(
                                                                        id: item.id,
                                                                        title: item.title,
                                                                        artist: item.subtitle ?? "Unknown",
                                                                        album: nil,
                                                                        durationMs: 0,
                                                                        coverArtUrl: item.imageUrl
                                                                    )
                                                                    audioManager.play(song: song)
                                                                    showFullScreenPlayer = true
                                                                    networkManager.recordHistory(songId: song.id)
                                                                }
                                                            }
                                                    }
                                                }
                                                .padding(.horizontal)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical)
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                networkManager.fetchDashboard()
            }
            .fullScreenCover(isPresented: $showFullScreenPlayer) {
                FullScreenPlayerView(isShowing: $showFullScreenPlayer)
            }
        }
    }
}

struct DashboardCardView: View {
    let item: DashboardItem
    
    var body: some View {
        VStack(alignment: .leading) {
            if item.type == "mood" {
                // Pill shape for moods
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(LinearGradient(gradient: Gradient(colors: [Theme.spiderRed, Theme.spiderNeonRed]), startPoint: .topLeading, endPoint: .bottomTrailing))
                    .cornerRadius(20)
                    .shadow(color: Theme.spiderNeonRed.opacity(0.4), radius: 5, x: 0, y: 3)
            } else {
                // Square card for songs/playlists
                ZStack(alignment: .bottomLeading) {
                    AsyncImage(url: URL(string: item.imageUrl ?? "")) { image in
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(Theme.spiderDarkGrey)
                    }
                    .frame(width: 140, height: 140)
                    .cornerRadius(12)
                    
                    // Dark gradient overlay for text readability
                    LinearGradient(gradient: Gradient(colors: [.clear, .black.opacity(0.8)]), startPoint: .top, endPoint: .bottom)
                        .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        if let subtitle = item.subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                    }
                    .padding(8)
                }
                .frame(width: 140, height: 140)
                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 5)
            }
        }
    }
}

struct SongRowView: View {
    let song: Song
    let isPlaying: Bool
    
    var body: some View {
        HStack(spacing: 15) {
            AsyncImage(url: URL(string: song.coverArtUrl ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            .frame(width: 60, height: 60)
            .cornerRadius(8)
            .shadow(color: isPlaying ? Theme.spiderNeonRed.opacity(0.5) : .clear, radius: 5, x: 0, y: 0)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.headline)
                    .foregroundColor(isPlaying ? Theme.spiderNeonRed : .white)
                    .lineLimit(1)
                Text(song.artist)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            Spacer()
            
            if isPlaying {
                Image(systemName: "waveform")
                    .foregroundColor(Theme.spiderNeonRed)
            } else {
                Text(formatTime(song.durationMs))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isPlaying ? Theme.spiderNeonRed.opacity(0.5) : Theme.spiderDarkGrey, lineWidth: 1)
        )
    }
    
    private func formatTime(_ ms: Int?) -> String {
        guard let ms = ms else { return "0:00" }
        let totalSeconds = ms / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
