import SwiftUI

struct FullScreenPlayerView: View {
    @StateObject private var audioManager = AudioPlayerManager.shared
    @StateObject private var networkManager = NetworkManager.shared
    @Binding var isShowing: Bool
    
    var body: some View {
        ZStack {
            Theme.SpiderBackground()
            
            VStack {
                // Header
                HStack {
                    Button(action: {
                        isShowing = false
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text("NOW PLAYING")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.spiderRed)
                        .tracking(2)
                    Spacer()
                    Button(action: {
                        // Options
                    }) {
                        Image(systemName: "ellipsis")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                .padding()
                
                Spacer()
                
                // Album Art with Spidey Glow
                if let song = audioManager.currentSong {
                    AsyncImage(url: URL(string: song.coverArtUrl ?? "")) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(Theme.spiderDarkGrey)
                    }
                    .frame(width: UIScreen.main.bounds.width - 60, height: UIScreen.main.bounds.width - 60)
                    .cornerRadius(20)
                    .shadow(color: Theme.spiderNeonRed.opacity(0.6), radius: 30, x: 0, y: 10)
                    .padding(.bottom, 40)
                    
                    // Song Info & Favorite
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(song.title)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Text(song.artist)
                                .font(.title3)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                        Spacer()
                        
                        Button(action: {
                            networkManager.addToFavorites(songId: song.id)
                        }) {
                            Image(systemName: networkManager.favorites.contains(where: { $0.id == song.id }) ? "heart.fill" : "heart")
                                .font(.title)
                                .foregroundColor(Theme.spiderNeonRed)
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    // Scrubber
                    VStack(spacing: 5) {
                        Slider(value: Binding(get: {
                            audioManager.progress
                        }, set: { newValue in
                            audioManager.seek(to: newValue)
                        }), in: 0...(audioManager.duration > 0 ? audioManager.duration : 1))
                        .accentColor(Theme.spiderNeonRed)
                        
                        HStack {
                            Text(formatTime(audioManager.progress))
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                            Text(formatTime(audioManager.duration))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 20)
                    
                    // Playback Controls
                    HStack(spacing: 40) {
                        Button(action: {
                            audioManager.playPrevious()
                        }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 35))
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
                                .font(.system(size: 80))
                                .foregroundColor(Theme.spiderRed)
                                .shadow(color: Theme.spiderNeonRed.opacity(0.5), radius: 10, x: 0, y: 0)
                        }
                        
                        Button(action: {
                            audioManager.playNext()
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 35))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.top, 30)
                    
                    Spacer()
                } else {
                    Text("No Song Playing")
                        .foregroundColor(.gray)
                    Spacer()
                }
            }
        }
        // Allow swiping down to dismiss
        .gesture(DragGesture().onEnded { value in
            if value.translation.height > 100 {
                isShowing = false
            }
        })
    }
    
    private func formatTime(_ time: Double) -> String {
        guard time.isFinite && !time.isNaN else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
