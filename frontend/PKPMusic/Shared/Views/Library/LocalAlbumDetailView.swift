import SwiftUI

struct LocalAlbumDetailView: View {
    let albumName: String
    let songs: [Song]
    @StateObject private var audioManager = AudioPlayerManager.shared
    @State private var showFullScreenPlayer = false
    
    var body: some View {
        ZStack {
            Theme.SpiderBackground()
            
            ScrollView {
                VStack(alignment: .center, spacing: 20) {
                    // Header
                    ZStack {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Theme.spiderDarkGrey)
                        
                        if let firstSongArt = songs.first?.coverArtUrl, let url = URL(string: firstSongArt) {
                            AsyncImage(url: url) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "opticaldisc").font(.system(size: 80)).foregroundColor(Theme.spiderNeonRed)
                            }
                            .frame(width: 250, height: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                        } else {
                            Image(systemName: "opticaldisc")
                                .font(.system(size: 80))
                                .foregroundColor(Theme.spiderNeonRed)
                        }
                    }
                    .frame(width: 250, height: 250)
                    .shadow(color: Theme.spiderNeonRed.opacity(0.3), radius: 20)
                    .padding(.top, 20)
                    
                    VStack(spacing: 8) {
                        Text(albumName)
                            .font(.title)
                            .bold()
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Text("\(songs.count) tracks")
                            .font(.caption)
                            .foregroundColor(Theme.spiderRed)
                    }
                    
                    // Songs
                    if !songs.isEmpty {
                        LazyVStack(spacing: 12) {
                            ForEach(songs.indices, id: \.self) { index in
                                let song = songs[index]
                                SongRowView(song: song, isPlaying: audioManager.currentSong?.id == song.id)
                                    .onTapGesture {
                                        audioManager.play(song: song, in: songs, at: index)
                                        showFullScreenPlayer = true
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showFullScreenPlayer) {
            FullScreenPlayerView(isShowing: $showFullScreenPlayer)
        }
    }
}
