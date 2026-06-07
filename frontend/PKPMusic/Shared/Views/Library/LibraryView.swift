import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @StateObject private var networkManager = NetworkManager.shared
    @StateObject private var audioManager = AudioPlayerManager.shared
    @State private var showFullScreenPlayer = false
    @State private var showFileImporter = false
    @State private var isImporting = false
    @State private var importMessage: String?
    @State private var localSearchText = ""
    
    // Segmented control state
    @State private var selectedTab = 0
    let tabs = ["Songs", "Playlists", "Albums"]
    
    @State private var showingCreateAlert = false
    @State private var newPlaylistName = ""
    
    var filteredSongs: [Song] {
        if localSearchText.isEmpty { return networkManager.favorites }
        return networkManager.favorites.filter { $0.title.lowercased().contains(localSearchText.lowercased()) || $0.artist.lowercased().contains(localSearchText.lowercased()) }
    }
    
    var filteredPlaylists: [Playlist] {
        if localSearchText.isEmpty { return networkManager.playlists }
        return networkManager.playlists.filter { $0.name.lowercased().contains(localSearchText.lowercased()) }
    }
    
    var groupedAlbums: [(name: String, songs: [Song])] {
        let grouped = Dictionary(grouping: networkManager.favorites) { $0.album ?? "Unknown Album" }
        return grouped.map { (name: $0.key, songs: $0.value) }.sorted { $0.name < $1.name }
    }
    
    var filteredAlbums: [(name: String, songs: [Song])] {
        let allAlbums = groupedAlbums
        if localSearchText.isEmpty { return allAlbums }
        return allAlbums.filter { $0.name.lowercased().contains(localSearchText.lowercased()) }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.SpiderBackground()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Library")
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(.white)
                        Spacer()
                        
                        if selectedTab == 1 {
                            Button(action: {
                                showingCreateAlert = true
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(Theme.spiderNeonRed)
                            }
                        }
                        
                        Button(action: {
                            showFileImporter = true
                        }) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.title2)
                                .foregroundColor(Theme.spiderNeonRed)
                        }
                        .padding(.leading, 10)
                    }
                    .padding()
                    
                    // Segmented Control
                    Picker("Library Tab", selection: $selectedTab) {
                        ForEach(0..<tabs.count, id: \.self) { index in
                            Text(tabs[index]).tag(index)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                    
                    // Local Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Filter your library...", text: $localSearchText)
                            .foregroundColor(.white)
                            .disableAutocorrection(true)
                            .autocapitalization(.none)
                        
                        if !localSearchText.isEmpty {
                            Button(action: {
                                localSearchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                    
                    if let message = importMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(Theme.spiderNeonRed)
                            .padding(.bottom, 5)
                    }
                    
                    if isImporting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.spiderNeonRed))
                            .padding()
                    }
                    
                    // Content
                    if selectedTab == 0 {
                        songsList
                    } else if selectedTab == 1 {
                        playlistsList
                    } else {
                        albumsList
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                networkManager.fetchFavorites()
                networkManager.fetchPlaylists()
            }
            .fullScreenCover(isPresented: $showFullScreenPlayer) {
                FullScreenPlayerView(isShowing: $showFullScreenPlayer)
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
                switch result {
                case .success(let url):
                    if url.startAccessingSecurityScopedResource() {
                        isImporting = true
                        importMessage = nil
                        networkManager.uploadCSV(fileURL: url) { success in
                            isImporting = false
                            if success {
                                importMessage = "Import started! Songs will appear soon."
                            } else {
                                importMessage = "Failed to upload file."
                            }
                        }
                        url.stopAccessingSecurityScopedResource()
                    }
                case .failure(let error):
                    print("File selection error: \(error.localizedDescription)")
                }
            }
            .alert("Create Playlist", isPresented: $showingCreateAlert) {
                TextField("Playlist Name", text: $newPlaylistName)
                Button("Cancel", role: .cancel) {
                    newPlaylistName = ""
                }
                Button("Create") {
                    if !newPlaylistName.isEmpty {
                        networkManager.createPlaylist(name: newPlaylistName)
                        newPlaylistName = ""
                    }
                }
            }
        }
    }
    
    private var songsList: some View {
        Group {
            if filteredSongs.isEmpty {
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 60))
                        .foregroundColor(Theme.spiderRed)
                    Text(localSearchText.isEmpty ? "No Songs Yet" : "No Results")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text(localSearchText.isEmpty ? "Your favorited tracks and imported CSV songs will appear here." : "Try searching for something else.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredSongs.indices, id: \.self) { index in
                            let song = filteredSongs[index]
                            SongRowView(song: song, isPlaying: audioManager.currentSong?.id == song.id)
                                .onTapGesture {
                                    audioManager.play(song: song, in: filteredSongs, at: index)
                                    showFullScreenPlayer = true
                                }
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
    }
    
    private var playlistsList: some View {
        Group {
            if filteredPlaylists.isEmpty {
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 60))
                        .foregroundColor(Theme.spiderRed)
                    
                    Text(localSearchText.isEmpty ? "No Playlists Yet" : "No Results")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(localSearchText.isEmpty ? "Create a playlist or import an Amazon Music CSV." : "Try searching for something else.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredPlaylists, id: \.id) { playlist in
                            let songCount = playlist.items?.count ?? 0
                            NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                                HStack(spacing: 15) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Theme.spiderDarkGrey)
                                            .frame(width: 60, height: 60)
                                        Image(systemName: "music.note.list")
                                            .foregroundColor(Theme.spiderRed)
                                            .font(.title2)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(playlist.name)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Text("\(songCount) songs")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding(10)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Theme.spiderDarkGrey, lineWidth: 1)
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.top)
                }
            }
        }
    }
    
    private var albumsList: some View {
        Group {
            if filteredAlbums.isEmpty {
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "opticaldisc")
                        .font(.system(size: 60))
                        .foregroundColor(Theme.spiderRed)
                    
                    Text(localSearchText.isEmpty ? "No Albums Yet" : "No Results")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(localSearchText.isEmpty ? "Your liked songs grouped by album will appear here." : "Try searching for something else.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredAlbums, id: \.name) { albumGroup in
                            NavigationLink(destination: LocalAlbumDetailView(albumName: albumGroup.name, songs: albumGroup.songs)) {
                                HStack(spacing: 15) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Theme.spiderDarkGrey)
                                            .frame(width: 60, height: 60)
                                        
                                        if let firstSongArt = albumGroup.songs.first?.coverArtUrl, let url = URL(string: firstSongArt) {
                                            AsyncImage(url: url) { image in
                                                image.resizable().aspectRatio(contentMode: .fill)
                                            } placeholder: {
                                                Image(systemName: "opticaldisc").foregroundColor(Theme.spiderRed).font(.title2)
                                            }
                                            .frame(width: 60, height: 60)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        } else {
                                            Image(systemName: "opticaldisc")
                                                .foregroundColor(Theme.spiderRed)
                                                .font(.title2)
                                        }
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(albumGroup.name)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        Text("\(albumGroup.songs.count) songs")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding(10)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Theme.spiderDarkGrey, lineWidth: 1)
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.top)
                }
            }
        }
    }
}
