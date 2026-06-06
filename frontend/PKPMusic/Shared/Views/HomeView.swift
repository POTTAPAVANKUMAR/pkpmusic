import SwiftUI

struct HomeView: View {
    @StateObject private var networkManager = NetworkManager.shared
    @StateObject private var audioManager = AudioPlayerManager.shared
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var showFullScreenPlayer = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.SpiderBackground()
                
                VStack(spacing: 0) {
                    // Modern Header (Search Bar)
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Find music, playlists, and more...", text: $searchText, onCommit: performSearch)
                            .foregroundColor(.white)
                            .disableAutocorrection(true)
                            .autocapitalization(.none)
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                isSearching = false
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(12)
                    .background(Theme.spiderDarkGrey.opacity(0.8))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    // Category Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            let categories = [
                                ("Telugu", "music.note", "telugu songs"),
                                ("Hindi", "music.note", "hindi songs"),
                                ("Pop", "music.mic", "pop music"),
                                ("R&B", "music.note.list", "r&b music"),
                                ("Artists", "person.2.fill", "top artists"),
                                ("Albums", "square.stack.fill", "top albums")
                            ]
                            
                            ForEach(0..<categories.count, id: \.self) { i in
                                Button(action: {
                                    searchText = categories[i].2
                                    performSearch()
                                }) {
                                    HStack {
                                        Image(systemName: categories[i].1)
                                        Text(categories[i].0)
                                    }
                                    .font(.system(size: 15, weight: .medium))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.1))
                                    .foregroundColor(.white)
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Theme.spiderNeonRed.opacity(0.3), lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 15)
                    .padding(.bottom, 5)
                    
                    if isSearching {
                        searchResultsView
                    } else if let error = networkManager.dashboardError {
                        Spacer()
                        VStack(spacing: 15) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .foregroundColor(Theme.spiderRed)
                            Text(error)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding()
                            Button("Try Again") {
                                networkManager.fetchDashboard()
                            }
                            .padding()
                            .background(Theme.spiderRed)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        Spacer()
                    } else if networkManager.dashboardSections.isEmpty {
                        Spacer()
                        ProgressView("Loading your music...")
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.spiderNeonRed))
                            .foregroundColor(.gray)
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 30) {
                                ForEach(networkManager.dashboardSections) { section in
                                    DashboardSectionView(section: section)
                                }
                            }
                            .padding(.top, 20)
                            .padding(.bottom, 100) // Space for mini player
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                if networkManager.dashboardSections.isEmpty {
                    networkManager.fetchDashboard()
                }
            }
            .fullScreenCover(isPresented: $showFullScreenPlayer) {
                FullScreenPlayerView(isShowing: $showFullScreenPlayer)
            }
        }
    }
    
    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(networkManager.searchResults) { song in
                    SongRowView(song: song, isPlaying: audioManager.currentSong?.id == song.id)
                        .onTapGesture {
                            audioManager.play(song: song, in: networkManager.searchResults, at: networkManager.searchResults.firstIndex(where: { $0.id == song.id }) ?? 0)
                            showFullScreenPlayer = true
                            
                            // Hide keyboard
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                        .padding(.horizontal)
                }
            }
            .padding(.top)
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        networkManager.searchYouTube(query: searchText)
    }
}

struct DashboardSectionView: View {
    let section: DashboardSection
    @StateObject private var audioManager = AudioPlayerManager.shared
    @State private var showFullScreenPlayer = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(section.title)
                .font(.title2)
                .bold()
                .foregroundColor(.white)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(section.items) { item in
                        if item.type == "song" {
                            Button(action: {
                                let song = Song(id: item.id, title: item.title, artist: item.subtitle ?? "Unknown", album: nil, durationMs: nil, coverArtUrl: item.imageUrl)
                                audioManager.play(song: song)
                                showFullScreenPlayer = true
                            }) {
                                DashboardItemCard(item: item)
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else if item.type == "mood" {
                            NavigationLink(destination: MoodPlaylistsView(params: item.id, moodTitle: item.title)) {
                                DashboardItemCard(item: item)
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            NavigationLink(destination: AlbumDetailView(albumId: item.id)) {
                                DashboardItemCard(item: item)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .fullScreenCover(isPresented: $showFullScreenPlayer) {
            FullScreenPlayerView(isShowing: $showFullScreenPlayer)
        }
    }
}

struct DashboardItemCard: View {
    let item: DashboardItem
    
    private func fallbackIcon(for type: String) -> String {
        switch type {
        case "song": return "music.note"
        case "playlist": return "music.note.list"
        case "mood": return "sparkles"
        case "artist": return "person.crop.circle.fill"
        case "album": return "opticaldisc"
        default: return "play.circle.fill"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image container
            ZStack {
                if let urlString = item.imageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Theme.spiderDarkGrey
                        }
                    }
                } else {
                    Theme.spiderDarkGrey
                    Image(systemName: fallbackIcon(for: item.type))
                        .foregroundColor(.gray)
                        .font(.largeTitle)
                }
            }
            .frame(width: 150, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
            
            // Text
            Text(item.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
            
            if let subtitle = item.subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
        }
        .frame(width: 150)
    }
}
