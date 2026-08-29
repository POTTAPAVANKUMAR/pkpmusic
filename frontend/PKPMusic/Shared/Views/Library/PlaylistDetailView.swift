import SwiftUI

struct PlaylistDetailView: View {
    let playlist: Playlist
    @Environment(\.dismiss) private var dismiss
    @StateObject private var networkManager = NetworkManager.shared
    @StateObject private var audioManager = AudioPlayerManager.shared
    @State private var showFullScreenPlayer = false
    @State private var showDeletePlaylistAlert = false
    @State private var localSearchText = ""
    
    // Live items if updated in networkManager
    private var currentPlaylist: Playlist {
        networkManager.playlists.first(where: { $0.id == playlist.id }) ?? playlist
    }
    
    var filteredItems: [PlaylistItem] {
        guard let items = currentPlaylist.items else { return [] }
        if localSearchText.isEmpty { return items }
        return items.filter { $0.song.title.lowercased().contains(localSearchText.lowercased()) || $0.song.artist.lowercased().contains(localSearchText.lowercased()) }
    }
    
    var body: some View {
        ZStack {
            Theme.SpiderBackground()
            
            VStack(spacing: 0) {
                // Local Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Find in playlist...", text: $localSearchText)
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
                .padding(.vertical, 10)
                
                if !filteredItems.isEmpty {
                    // Action Buttons: Play & Shuffle
                    HStack(spacing: 20) {
                        Button(action: {
                            audioManager.isShuffled = false
                            let songs = currentPlaylist.items?.map { $0.song } ?? []
                            if !songs.isEmpty {
                                audioManager.play(song: songs[0], in: songs, at: 0)
                                showFullScreenPlayer = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Play")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.spiderNeonRed)
                            .cornerRadius(25)
                        }
                        .buttonStyle(SpiderButtonStyle())
                        
                        Button(action: {
                            audioManager.isShuffled = true
                            let songs = currentPlaylist.items?.map { $0.song } ?? []
                            if let randomSong = songs.randomElement() {
                                audioManager.play(song: randomSong, in: songs, at: 0)
                                showFullScreenPlayer = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "shuffle")
                                Text("Shuffle")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.spiderDarkGrey)
                            .cornerRadius(25)
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Theme.spiderNeonRed.opacity(0.5), lineWidth: 1)
                            )
                        }
                        .buttonStyle(SpiderButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)

                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredItems.indices, id: \.self) { index in
                                let item = filteredItems[index]
                                HStack {
                                    SongRowView(song: item.song, isPlaying: audioManager.currentSong?.id == item.song.id)
                                        .onTapGesture {
                                            let songs = filteredItems.map { $0.song }
                                            audioManager.play(song: item.song, in: songs, at: index)
                                            showFullScreenPlayer = true
                                        }
                                    
                                    Button(action: {
                                        networkManager.removeSongFromPlaylist(songId: item.song.id, playlistId: currentPlaylist.id)
                                    }) {
                                        Image(systemName: "minus.circle")
                                            .font(.system(size: 18))
                                            .foregroundColor(.gray.opacity(0.6))
                                    }
                                    .padding(.trailing, 4)
                                }
                                .padding(.horizontal)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        networkManager.removeSongFromPlaylist(songId: item.song.id, playlistId: currentPlaylist.id)
                                    } label: {
                                        Label("Remove from Playlist", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                } else {
                    Spacer()
                    VStack(spacing: 20) {
                        Image(systemName: "music.note")
                            .font(.system(size: 60))
                            .foregroundColor(Theme.spiderRed)
                        Text("Playlist is Empty")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("Add songs from the player view.")
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
            }
        }
        .navigationTitle(currentPlaylist.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showDeletePlaylistAlert = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(Theme.spiderRed)
                }
            }
        }
        .alert("Delete Playlist", isPresented: $showDeletePlaylistAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                networkManager.deletePlaylist(playlistId: currentPlaylist.id) { success in
                    if success {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete '\(currentPlaylist.name)'? This action cannot be undone.")
        }
        .fullScreenCover(isPresented: $showFullScreenPlayer) {
            FullScreenPlayerView(isShowing: $showFullScreenPlayer)
        }
    }
}
