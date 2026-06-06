import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @StateObject private var networkManager = NetworkManager.shared
    @StateObject private var audioManager = AudioPlayerManager.shared
    @State private var showFullScreenPlayer = false
    @State private var showFileImporter = false
    @State private var isImporting = false
    @State private var importMessage: String?
    
    // Segmented control state
    @State private var selectedTab = 0
    let tabs = ["Songs", "Playlists"]
    
    @State private var showingCreateAlert = false
    @State private var newPlaylistName = ""
    
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
                    } else {
                        playlistsList
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
            if networkManager.favorites.isEmpty {
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 60))
                        .foregroundColor(Theme.spiderRed)
                    Text("No Songs Yet")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Your favorited tracks and imported CSV songs will appear here.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(networkManager.favorites.indices, id: \.self) { index in
                            let song = networkManager.favorites[index]
                            SongRowView(song: song, isPlaying: audioManager.currentSong?.id == song.id)
                                .onTapGesture {
                                    audioManager.play(song: song, in: networkManager.favorites, at: index)
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
            if networkManager.playlists.isEmpty {
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 60))
                        .foregroundColor(Theme.spiderRed)
                    
                    Text("No Playlists Yet")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Create a playlist or import an Amazon Music CSV.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(networkManager.playlists, id: \.id) { playlist in
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
}
