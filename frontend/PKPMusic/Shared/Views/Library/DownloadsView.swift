import SwiftUI

struct DownloadsView: View {
    @ObservedObject var downloadManager = DownloadManager.shared
    @ObservedObject var player = AudioPlayerManager.shared
    
    var body: some View {
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
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(downloadManager.downloadedSongs.enumerated()), id: \.element.id) { index, song in
                            HStack {
                                Button(action: {
                                    player.play(song: song, in: downloadManager.downloadedSongs, at: index)
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
    }
}
