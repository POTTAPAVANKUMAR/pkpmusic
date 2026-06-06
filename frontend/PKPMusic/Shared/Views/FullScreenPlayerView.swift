import SwiftUI

struct FullScreenPlayerView: View {
    @StateObject private var audioManager = AudioPlayerManager.shared
    @Binding var isShowing: Bool
    
    @State private var volume: Double = 0.5
    @State private var progress: Double = 0.0
    
    var body: some View {
        ZStack {
            // Background blur based on album art (simulated with a gradient for now)
            LinearGradient(gradient: Gradient(colors: [.purple.opacity(0.8), .black]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                // Drag down indicator
                Capsule()
                    .fill(Color.secondary)
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)
                
                Spacer()
                
                // Album Art
                if let currentSong = audioManager.currentSong,
                   let coverUrl = currentSong.coverArtUrl,
                   let url = URL(string: coverUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: UIScreen.main.bounds.width - 60, height: UIScreen.main.bounds.width - 60)
                    .cornerRadius(15)
                    .shadow(radius: 10)
                    .padding(.bottom, 40)
                } else {
                    RoundedRectangle(cornerRadius: 15)
                        .fill(LinearGradient(gradient: Gradient(colors: [.pink, .purple]), startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: UIScreen.main.bounds.width - 60, height: UIScreen.main.bounds.width - 60)
                        .shadow(radius: 10)
                        .padding(.bottom, 40)
                }
                
                // Song Info
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(audioManager.currentSong?.title ?? "Not Playing")
                            .font(.system(size: 24, weight: .bold, design: .default))
                            .foregroundColor(.white)
                        
                        Text(audioManager.currentSong?.artist ?? "")
                            .font(.system(size: 18, weight: .medium, design: .default))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                    Button(action: {
                        if let current = audioManager.currentSong {
                            NetworkManager.shared.addToFavorites(songId: current.id)
                        }
                    }) {
                        Image(systemName: "heart")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 30)
                
                // Scrubber (Placeholder)
                Slider(value: $progress, in: 0...100)
                    .accentColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.top, 20)
                
                // Playback Controls
                HStack(spacing: 40) {
                    Button(action: {
                        audioManager.playPrevious()
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                    }
                    
                    Button(action: {
                        if audioManager.isPlaying {
                            audioManager.pause()
                        } else {
                            audioManager.resume()
                        }
                    }) {
                        Image(systemName: audioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 70))
                            .foregroundColor(.white)
                    }
                    
                    Button(action: {
                        audioManager.playNext()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                    }
                }
                .padding(.top, 30)
                
                // Volume Slider (Placeholder)
                HStack {
                    Image(systemName: "speaker.fill")
                        .foregroundColor(.white.opacity(0.7))
                    Slider(value: $volume, in: 0...1)
                        .accentColor(.white)
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 30)
                .padding(.top, 40)
                
                Spacer()
            }
        }
        // Allow swiping down to dismiss
        .gesture(DragGesture().onEnded { value in
            if value.translation.height > 100 {
                isShowing = false
            }
        })
    }
}
