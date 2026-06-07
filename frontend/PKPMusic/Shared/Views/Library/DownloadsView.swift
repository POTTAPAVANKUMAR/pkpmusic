import SwiftUI

struct DownloadsView: View {
    @ObservedObject var downloadManager = DownloadManager.shared
    @ObservedObject var player = AudioPlayerManager.shared
    @State private var searchQuery = ""
    
    var filteredSongs: [Song] {
        if searchQuery.isEmpty {
            return downloadManager.downloadedSongs
        } else {
            return downloadManager.downloadedSongs.filter { song in
                song.title.localizedCaseInsensitiveContains(searchQuery) ||
                song.artist.localizedCaseInsensitiveContains(searchQuery)
            }
        }
    }
    
    var body: some View {
        NavigationView {
        ZStack {
            Theme.spiderDarkGrey.ignoresSafeArea()
            
            if downloadManager.downloadedSongs.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No offline music")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Download songs to listen without an internet connection.")
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else if filteredSongs.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No results found")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(filteredSongs.enumerated()), id: \.element.id) { index, song in
                            HStack {
                                Button(action: {
                                    player.play(song: song, in: filteredSongs, at: index)
                                }) {
                                    SongRowView(song: song, isPlaying: player.currentSong?.id == song.id)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Button(action: {
                                    downloadManager.removeDownload(songId: song.id)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(Theme.spiderNeonRed)
                                        .padding()
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Downloads")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchQuery, prompt: "Search offline songs...")
        }
    }
}
