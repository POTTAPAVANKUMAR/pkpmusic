import SwiftUI

struct MiniPlayerView: View {
    @StateObject private var audioManager = AudioPlayerManager.shared
    @State private var isShowingFullScreen = false
    
    var body: some View {
        if let currentSong = audioManager.currentSong {
            HStack {
                if let coverUrl = currentSong.coverArtUrl, let url = URL(string: coverUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 44, height: 44)
                    .cornerRadius(6)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(gradient: Gradient(colors: [.purple, .pink]), startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                }
                
                VStack(alignment: .leading) {
                    Text(currentSong.title)
                        .font(.subheadline)
                        .bold()
                        .lineLimit(1)
                    
                    Text(currentSong.artist)
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                .padding(.trailing, 10)
            }
            .padding(10)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .padding(.horizontal)
            .shadow(radius: 5)
            .onTapGesture {
                if audioManager.currentSong != nil {
                    isShowingFullScreen = true
                }
            }
            .fullScreenCover(isPresented: $isShowingFullScreen) {
                FullScreenPlayerView(isShowing: $isShowingFullScreen)
            }
        }
    }
}

