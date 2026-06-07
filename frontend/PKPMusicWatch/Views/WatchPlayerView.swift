import SwiftUI

struct WatchPlayerView: View {
    @EnvironmentObject var audioManager: AudioPlayerManager
    
    var body: some View {
        VStack {
            if let song = audioManager.currentSong {
                Text(song.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(song.artist)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                Spacer()
                
                HStack(spacing: 20) {
                    Button(action: {
                        audioManager.playPrevious()
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.title3)
                    }
                    
                    Button(action: {
                        if audioManager.isPlaying {
                            audioManager.pause()
                        } else {
                            audioManager.resume()
                        }
                    }) {
                        Image(systemName: audioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        audioManager.playNext()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.title3)
                    }
                }
            } else {
                Text("Not Playing")
                    .foregroundColor(.gray)
            }
        }
        .padding()
    }
}
