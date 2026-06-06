import SwiftUI

struct PlaylistDetailView: View {
    let playlist: Playlist
    @StateObject private var audioManager = AudioPlayerManager.shared
    @State private var showFullScreenPlayer = false
    
    var body: some View {
        ZStack {
            Theme.SpiderBackground()
            
            VStack {
                if let items = playlist.items, !items.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(items.indices, id: \.self) { index in
                                let item = items[index]
                                HStack {
                                    AsyncImage(url: URL(string: item.song.coverArtUrl ?? "")) { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Color.gray.opacity(0.3)
                                    }
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(8)
                                    .shadow(color: Theme.spiderNeonRed.opacity(0.3), radius: 5, x: 0, y: 0)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.song.title)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        Text(item.song.artist)
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    
                                    if audioManager.currentSong?.id == item.song.id {
                                        Image(systemName: "waveform")
                                            .foregroundColor(Theme.spiderNeonRed)
                                    }
                                }
                                .padding(10)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Theme.spiderDarkGrey, lineWidth: 1)
                                )
                                .padding(.horizontal)
                                .onTapGesture {
                                    let songs = items.map { $0.song }
                                    audioManager.play(song: item.song, in: songs, at: index)
                                    showFullScreenPlayer = true
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
        .navigationTitle(playlist.name)
        .fullScreenCover(isPresented: $showFullScreenPlayer) {
            FullScreenPlayerView(isShowing: $showFullScreenPlayer)
        }
    }
}
