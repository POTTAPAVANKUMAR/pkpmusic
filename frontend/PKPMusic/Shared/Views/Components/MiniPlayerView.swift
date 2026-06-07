import SwiftUI

struct MiniPlayerView: View {
    @StateObject private var audioManager = AudioPlayerManager.shared
    @State private var isShowingFullScreen = false
    
    @State private var dragOffset: CGSize = .zero
    @State private var position: CGSize = CGSize(width: 0, height: -80) // Default start position above TabBar
    
    var body: some View {
        if let song = audioManager.currentSong {
            HStack(spacing: 12) {
                // Album Art (Circular)
                AsyncImage(url: URL(string: song.coverArtUrl ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 45, height: 45)
                .clipShape(Circle())
                .shadow(color: Theme.spiderNeonRed.opacity(0.4), radius: 4, x: 0, y: 0)
                
                // Play/Pause
                Button(action: {
                    if audioManager.isPlaying {
                        audioManager.pause()
                    } else {
                        audioManager.resume()
                    }
                }) {
                    Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Theme.spiderRed)
                        .frame(width: 30, height: 30)
                }
                
                // Next Track
                Button(action: {
                    audioManager.playNext()
                }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 35)
                    .fill(Theme.spiderDarkGrey.opacity(0.95))
                    .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 35)
                            .stroke(Theme.spiderNeonRed.opacity(0.5), lineWidth: 1)
                    )
            )
            // Tap to open full player
            .onTapGesture {
                isShowingFullScreen = true
            }
            .fullScreenCover(isPresented: $isShowingFullScreen) {
                FullScreenPlayerView(isShowing: $isShowingFullScreen)
            }
            // Draggable Floating Behavior
            .offset(x: position.width + dragOffset.width, y: position.height + dragOffset.height)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            position.width += value.translation.width
                            position.height += value.translation.height
                            dragOffset = .zero
                            
                            // Screen bounds to snap and prevent getting lost
                            let screenWidth = UIScreen.main.bounds.width
                            let screenHeight = UIScreen.main.bounds.height
                            
                            let xLimit = (screenWidth / 2) - 40
                            if position.width > xLimit { position.width = xLimit }
                            if position.width < -xLimit { position.width = -xLimit }
                            
                            if position.height > -60 { position.height = -60 } // Don't go below tab bar
                            if position.height < -screenHeight + 100 { position.height = -screenHeight + 100 } // Don't go above top notch
                        }
                    }
            )
        }
    }
}
