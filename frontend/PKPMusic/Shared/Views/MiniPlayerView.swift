import SwiftUI

struct MiniPlayerView: View {
    @StateObject private var audioManager = AudioPlayerManager.shared
    @State private var isShowingFullScreen = false
    
    var body: some View {
        if let currentSong = audioManager.currentSong {
            HStack {
                VStack {
                    Spacer()
                    if let song = audioManager.currentSong {
                        HStack(spacing: 12) {
                            AsyncImage(url: URL(string: song.coverArtUrl ?? "")) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Color.gray.opacity(0.3)
                            }
                            .frame(width: 45, height: 45)
                            .cornerRadius(8)
                            .shadow(color: Theme.spiderNeonRed.opacity(0.4), radius: 4, x: 0, y: 0)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(song.title)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(song.artist)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                if audioManager.isPlaying {
                                    audioManager.pause()
                                } else {
                                    audioManager.resume()
                                }
                            }) {
                                Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(Theme.spiderRed)
                            }
                            
                            Button(action: {
                                audioManager.playNext()
                            }) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 30)
                                .fill(Theme.spiderDarkGrey.opacity(0.95))
                                .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 30)
                                        .stroke(Theme.spiderNeonRed.opacity(0.5), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 10)
                        .padding(.bottom, 60) // Above TabBar
                        .onTapGesture {
                            isShowingFullScreen = true
                        }
                        .fullScreenCover(isPresented: $isShowingFullScreen) {
                            FullScreenPlayerView(isShowing: $isShowingFullScreen)
                        }
                    }
                }
            }
        }
    }
}
