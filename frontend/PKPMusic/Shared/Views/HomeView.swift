import SwiftUI

struct HomeView: View {
    @StateObject private var networkManager = NetworkManager.shared
    @StateObject private var audioManager = AudioPlayerManager.shared
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var searchResults: [Song] = []
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
                                searchResults.removeAll()
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
                ForEach(searchResults) { song in
                    SongRowView(song: song, isPlaying: audioManager.currentSong?.id == song.id)
                        .onTapGesture {
                            audioManager.play(song: song, in: searchResults, at: searchResults.firstIndex(where: { $0.id == song.id }) ?? 0)
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
        
        networkManager.search(query: searchText) { results in
            DispatchQueue.main.async {
                self.searchResults = results
            }
        }
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
                        DashboardItemCard(item: item)
                            .onTapGesture {
                                if item.type == "song" {
                                    // Convert to Song model and play
                                    let song = Song(id: item.id, title: item.title, artist: item.subtitle ?? "Unknown", album: nil, durationMs: nil, coverArtUrl: item.imageUrl)
                                    audioManager.play(song: song)
                                    showFullScreenPlayer = true
                                }
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image container
            ZStack {
                if let urlString = item.imageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Color(Theme.spiderDarkGrey)
                        }
                    }
                } else {
                    Color(Theme.spiderDarkGrey)
                    Image(systemName: item.type == "song" ? "music.note" : "square.stack.fill")
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
