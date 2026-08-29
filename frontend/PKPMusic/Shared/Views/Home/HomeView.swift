import SwiftUI

struct HomeView: View {
    @StateObject private var networkManager = NetworkManager.shared
    @StateObject private var audioManager = AudioPlayerManager.shared
    @StateObject private var authManager = AuthManager.shared
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var showFullScreenPlayer = false
    @State private var selectedSearchType = 0 // 0: Songs, 1: Albums, 2: Artists
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.SpiderBackground()
                
                VStack(spacing: 0) {
                    // Modern Header (Search Bar & Logout)
                    HStack(spacing: 12) {
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
                        
                        NavigationLink(destination: ProfileSettingsView()) {
                            ProfileImageView(urlString: authManager.currentUserProfilePicture)
                                .frame(width: 35, height: 35)
                                .clipShape(Circle())
                        }
                        
                        Button(action: {
                            authManager.logout()
                        }) {
                            Image(systemName: "rectangle.portrait.and.arrow.forward")
                                .font(.title2)
                                .foregroundColor(Theme.spiderRed)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    // Category Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            let categories = [
                                ("Telugu", "music.note", "telugu songs"),
                                ("English", "music.note", "english songs"),
                                ("Tamil", "music.note", "tamil songs"),
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
                        VStack(spacing: 0) {
                            Picker("Search Type", selection: $selectedSearchType) {
                                Text("Songs").tag(0)
                                Text("Albums").tag(1)
                                Text("Artists").tag(2)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(.horizontal)
                            .padding(.bottom, 10)
                            .onChange(of: selectedSearchType) { _, _ in
                                performSearch()
                            }
                            
                            searchResultsView
                        }
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
                            VStack(spacing: 26) {
                                // Dynamic Hero Greeting Banner
                                heroGreetingBanner
                                
                                ForEach(networkManager.dashboardSections) { section in
                                    DashboardSectionView(section: section)
                                }
                            }
                            .padding(.top, 4)
                            .padding(.bottom, 100) // Space for mini player
                        }
                        .refreshable {
                            networkManager.fetchDashboard()
                            networkManager.fetchFavorites()
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                if networkManager.dashboardSections.isEmpty {
                    networkManager.fetchDashboard()
                }
                networkManager.fetchFavorites()
            }
            .fullScreenCover(isPresented: $showFullScreenPlayer) {
                FullScreenPlayerView(isShowing: $showFullScreenPlayer)
            }
        }
    }
    
    // MARK: - Dynamic Hero Greeting Banner
    private var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        else if hour < 18 { return "Good afternoon" }
        else { return "Good evening" }
    }
    
    private var userGreetingName: String {
        if let name = authManager.currentUserName, !name.isEmpty {
            return name
        }
        if let email = authManager.currentUserEmail, !email.isEmpty {
            return email.components(separatedBy: "@").first ?? "Music Lover"
        }
        return "Music Lover"
    }

    private func playFavoritesOrTopTrack() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        
        if !networkManager.favorites.isEmpty {
            let firstSong = networkManager.favorites[0]
            audioManager.play(song: firstSong, in: networkManager.favorites, at: 0)
            showFullScreenPlayer = true
            return
        }
        
        // Fallback to first song in dashboard
        for section in networkManager.dashboardSections {
            if let firstItem = section.items.first(where: { $0.type == "song" }) {
                let song = Song(id: firstItem.id, title: firstItem.title, artist: firstItem.subtitle ?? "Unknown", album: nil, albumId: nil, durationMs: nil, coverArtUrl: firstItem.imageUrl)
                audioManager.play(song: song)
                showFullScreenPlayer = true
                return
            }
        }
    }

    @ViewBuilder
    private var heroGreetingBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("\(timeGreeting), \(userGreetingName)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.neonAccent)
                    .tracking(0.5)
                
                Spacer()
                
                Text("PRO")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Theme.spiderNeonRed)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.spiderNeonRed.opacity(0.15))
                    .cornerRadius(8)
            }
            
            Text("Ready for your daily music flow?")
                .font(.system(size: 23, weight: .heavy))
                .foregroundColor(.white)
                .lineLimit(2)
            
            Text("Explore personalized recommendations and curated tracks synced across your devices.")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.gray.opacity(0.9))
                .lineLimit(3)
                .lineSpacing(2)
            
            Button(action: playFavoritesOrTopTrack) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Play Favorites")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Theme.spiderNeonRed, Color.red.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(24)
                .shadow(color: Theme.spiderNeonRed.opacity(0.4), radius: 10, x: 0, y: 4)
            }
            .padding(.top, 4)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            Theme.spiderNeonRed.opacity(0.18),
                            Color.purple.opacity(0.12),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            LinearGradient(
                                colors: [Theme.spiderNeonRed.opacity(0.4), Color.white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    @ViewBuilder
    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if selectedSearchType == 0 {
                    songSearchResultsView
                } else if selectedSearchType == 1 {
                    albumSearchResultsView
                } else if selectedSearchType == 2 {
                    artistSearchResultsView
                }
            }
            .padding(.top)
        }
    }
    
    @ViewBuilder
    private var songSearchResultsView: some View {
        ForEach(networkManager.searchResults) { song in
            SongRowView(song: song, isPlaying: audioManager.currentSong?.id == song.id)
                .onTapGesture {
                    audioManager.play(song: song, in: networkManager.searchResults, at: networkManager.searchResults.firstIndex(where: { $0.id == song.id }) ?? 0)
                    showFullScreenPlayer = true
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var albumSearchResultsView: some View {
        ForEach(networkManager.searchAlbumResults) { album in
            NavigationLink(destination: AlbumDetailView(albumId: album.id)) {
                HStack {
                    if let urlString = album.coverArtUrl, let url = URL(string: urlString) {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "opticaldisc").foregroundColor(.gray)
                        }
                        .frame(width: 50, height: 50)
                        .cornerRadius(5)
                    } else {
                        Image(systemName: "opticaldisc").frame(width: 50, height: 50).background(Color.gray.opacity(0.3)).cornerRadius(5)
                    }
                    
                    VStack(alignment: .leading) {
                        Text(album.title).foregroundColor(.white).bold()
                        Text(album.artist).foregroundColor(.gray).font(.caption)
                    }
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
    }
    
    @ViewBuilder
    private var artistSearchResultsView: some View {
        ForEach(networkManager.searchArtistResults) { artist in
            NavigationLink(destination: ArtistDetailView(artistId: artist.id, artistName: artist.artist)) {
                HStack {
                    if let urlString = artist.coverArtUrl, let url = URL(string: urlString) {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "person.circle.fill").foregroundColor(.gray)
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill").frame(width: 50, height: 50).background(Color.gray.opacity(0.3)).clipShape(Circle())
                    }
                    
                    Text(artist.artist).foregroundColor(.white).bold()
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        if selectedSearchType == 0 {
            networkManager.searchYouTube(query: searchText)
        } else if selectedSearchType == 1 {
            networkManager.searchYouTubeAlbums(query: searchText)
        } else if selectedSearchType == 2 {
            networkManager.searchYouTubeArtists(query: searchText)
        }
    }
}

struct DashboardSectionView: View {
    let section: DashboardSection
    @StateObject private var audioManager = AudioPlayerManager.shared
    @State private var showFullScreenPlayer = false
    
    @State private var selectedMood: DashboardItem?
    @State private var selectedAlbum: DashboardItem?
    @State private var selectedArtist: DashboardItem?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text(section.title)
                    .font(.title2)
                    .bold()
                    .foregroundColor(.white)
                
                if section.title.contains("AI Recommended") {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)
                }
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(section.items) { item in
                        if item.type == "song" {
                            Button(action: {
                                let song = Song(id: item.id, title: item.title, artist: item.subtitle ?? "Unknown", album: nil, albumId: nil, durationMs: nil, coverArtUrl: item.imageUrl)
                                audioManager.play(song: song)
                                showFullScreenPlayer = true
                            }) {
                                DashboardItemCard(item: item)
                            }
                            .buttonStyle(SpiderButtonStyle())
                        } else if item.type == "mood" {
                            Button(action: {
                                selectedMood = item
                            }) {
                                DashboardItemCard(item: item)
                            }
                            .buttonStyle(SpiderButtonStyle())
                        } else if item.type == "artist" {
                            Button(action: {
                                selectedArtist = item
                            }) {
                                DashboardItemCard(item: item)
                            }
                            .buttonStyle(SpiderButtonStyle())
                        } else {
                            Button(action: {
                                selectedAlbum = item
                            }) {
                                DashboardItemCard(item: item)
                            }
                            .buttonStyle(SpiderButtonStyle())
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // Programmatic Navigation Links
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedMood != nil },
            set: { if !$0 { selectedMood = nil } }
        )) {
            if let mood = selectedMood {
                MoodPlaylistsView(params: mood.id, moodTitle: mood.title)
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedAlbum != nil },
            set: { if !$0 { selectedAlbum = nil } }
        )) {
            if let album = selectedAlbum {
                AlbumDetailView(albumId: album.id)
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedArtist != nil },
            set: { if !$0 { selectedArtist = nil } }
        )) {
            if let artist = selectedArtist {
                ArtistDetailView(artistId: artist.id, artistName: artist.title)
            }
        }
        .fullScreenCover(isPresented: $showFullScreenPlayer) {
            FullScreenPlayerView(isShowing: $showFullScreenPlayer)
        }
    }
}

struct SpiderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0.5), value: configuration.isPressed)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.spiderNeonRed.opacity(configuration.isPressed ? 0.5 : 0), lineWidth: 2)
                    .scaleEffect(configuration.isPressed ? 1.05 : 1.0)
                    .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
            )
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
    
    private func getDynamicIcon(for title: String, type: String) -> String {
        let lower = title.lowercased()
        if lower.contains("chill") { return "wind" }
        if lower.contains("workout") || lower.contains("energize") { return "figure.run" }
        if lower.contains("party") { return "party.popper.fill" }
        if lower.contains("romance") || lower.contains("love") { return "heart.fill" }
        if lower.contains("sad") { return "cloud.rain.fill" }
        if lower.contains("sleep") { return "moon.zzz.fill" }
        if lower.contains("focus") { return "brain.head.profile" }
        if lower.contains("gaming") { return "gamecontroller.fill" }
        if lower.contains("commute") { return "car.fill" }
        if lower.contains("feel good") { return "sun.max.fill" }
        if lower.contains("classical") { return "pianokeys" }
        if lower.contains("jazz") || lower.contains("blues") { return "guitars.fill" }
        if lower.contains("metal") || lower.contains("rock") { return "guitars.fill" }
        if lower.contains("dance") || lower.contains("electronic") { return "waveform.circle.fill" }
        if lower.contains("family") { return "figure.2.and.child.holdinghands" }
        if lower.contains("decades") { return "clock.fill" }
        if lower.contains("pop") { return "music.mic" }
        if lower.contains("country") { return "guitars" }
        if lower.contains("indie") { return "leaf.fill" }
        
        return fallbackIcon(for: type)
    }
    
    private func getDynamicGradient(for title: String) -> LinearGradient {
        let colorPairs: [[Color]] = [
            [.blue, .purple],
            [Theme.spiderNeonRed, .black],
            [.orange, .red],
            [.green, .blue],
            [.pink, .purple],
            [.yellow, .orange],
            [.cyan, .blue],
            [.purple, Theme.spiderNeonRed]
        ]
        // Pseudo-random but consistent based on title
        let hash = abs(title.hashValue) % colorPairs.count
        return LinearGradient(gradient: Gradient(colors: colorPairs[hash]), startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    var body: some View {
        VStack(alignment: item.type == "artist" ? .center : .leading, spacing: 8) {
            // Image container
            ZStack(alignment: .bottomTrailing) {
                if let urlString = item.imageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Theme.spiderDarkGrey
                        }
                    }
                } else {
                    if item.type == "mood" || item.type == "genre" || item.type == "playlist" {
                        getDynamicGradient(for: item.title)
                        Image(systemName: getDynamicIcon(for: item.title, type: item.type))
                            .foregroundColor(.white)
                            .font(.system(size: 44))
                            .shadow(color: .black.opacity(0.5), radius: 5)
                    } else {
                        Theme.spiderDarkGrey
                        Image(systemName: fallbackIcon(for: item.type))
                            .foregroundColor(.gray)
                            .font(.largeTitle)
                    }
                }
                
                // Floating Play Indicator on songs & albums
                if item.type == "song" || item.type == "album" || item.type == "playlist" {
                    Circle()
                        .fill(Theme.spiderNeonRed)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                        .padding(8)
                }
            }
            .frame(width: 146, height: 146)
            .clipShape(item.type == "artist" ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 14)))
            .overlay(
                item.type == "artist" ?
                    AnyView(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)) :
                    AnyView(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
            )
            .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)
            
            // Text
            VStack(alignment: item.type == "artist" ? .center : .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray.opacity(0.85))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: item.type == "artist" ? .center : .leading)
        }
        .frame(width: 146)
    }
}

struct AnyShape: Shape {
    private let _path: (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        _path = shape.path(in:)
    }

    func path(in rect: CGRect) -> Path {
        return _path(rect)
    }
}

