import SwiftUI

struct SongRowView: View {
    let song: Song
    let isPlaying: Bool
    @ObservedObject var downloadManager = DownloadManager.shared
    @StateObject private var audioManager = AudioPlayerManager.shared
    @StateObject private var networkManager = NetworkManager.shared
    @State private var showingPlaylists = false
    
    var body: some View {
        HStack(spacing: 15) {
            AsyncImage(url: URL(string: song.coverArtUrl ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                ZStack {
                    Theme.spiderDarkGrey
                    Image(systemName: "music.note")
                        .foregroundColor(.gray)
                }
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
                if audioManager.isLoading && audioManager.currentSong?.id == song.id {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.spiderNeonRed))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "waveform")
                        .foregroundColor(Theme.spiderNeonRed)
                }
            } else {
                Text(formatTime(song.durationMs))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Download button
            if downloadManager.isDownloaded(songId: song.id) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Theme.spiderNeonRed)
            } else if let progress = downloadManager.activeDownloads[song.id] {
                ProgressView(value: progress)
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.spiderNeonRed))
                    .frame(width: 20, height: 20)
            } else {
                Button(action: {
                    downloadManager.download(song: song)
                }) {
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isPlaying ? Theme.spiderNeonRed.opacity(0.5) : Theme.spiderDarkGrey, lineWidth: 1)
        )
        .contextMenu {
            Button(action: {
                AudioPlayerManager.shared.insertNext(song: song)
            }) {
                Label("Play Next", systemImage: "text.insert")
            }
            
            Button(action: {
                AudioPlayerManager.shared.addToQueue(song: song)
            }) {
                Label("Add to Queue", systemImage: "text.badge.plus")
            }
            
            Divider()
            
            Button(action: {
                if downloadManager.isDownloaded(songId: song.id) {
                    downloadManager.removeDownload(songId: song.id)
                } else {
                    downloadManager.download(song: song)
                }
            }) {
                Label(downloadManager.isDownloaded(songId: song.id) ? "Remove Download" : "Download", 
                      systemImage: downloadManager.isDownloaded(songId: song.id) ? "trash" : "arrow.down.circle")
            }
            
            Button(action: {
                networkManager.addToFavorites(songId: song.id)
            }) {
                Label(networkManager.favorites.contains(where: { $0.id == song.id }) ? "Remove from Favorites" : "Add to Favorites", 
                      systemImage: networkManager.favorites.contains(where: { $0.id == song.id }) ? "heart.fill" : "heart")
            }
            
            Button(action: {
                networkManager.fetchPlaylists()
                showingPlaylists = true
            }) {
                Label("Add to Playlist", systemImage: "music.note.list")
            }
        }
        .sheet(isPresented: $showingPlaylists) {
            NavigationView {
                List {
                    if networkManager.playlists.isEmpty {
                        Text("No playlists found. Create one in the Playlists tab!")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(networkManager.playlists, id: \.id) { playlist in
                            Button(action: {
                                networkManager.addSongToPlaylist(songId: song.id, playlistId: playlist.id)
                                showingPlaylists = false
                            }) {
                                Text(playlist.name)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
                .navigationTitle("Select Playlist")
                .navigationBarItems(trailing: Button("Cancel") {
                    showingPlaylists = false
                })
            }
        }
    }
    
    private func formatTime(_ ms: Int?) -> String {
        guard let ms = ms else { return "--:--" }
        let totalSeconds = ms / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
