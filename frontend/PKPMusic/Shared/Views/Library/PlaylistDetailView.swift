import SwiftUI

struct PlaylistDetailView: View {
    let playlist: Playlist
    @StateObject private var audioManager = AudioPlayerManager.shared
    @State private var showFullScreenPlayer = false
    
    @State private var localSearchText = ""
    
    var filteredItems: [PlaylistItem] {
        guard let items = playlist.items else { return [] }
        if localSearchText.isEmpty { return items }
        return items.filter { $0.song.title.lowercased().contains(localSearchText.lowercased()) || $0.song.artist.lowercased().contains(localSearchText.lowercased()) }
    }
    
    var body: some View {
        ZStack {
            Theme.SpiderBackground()
            
            VStack(spacing: 0) {
                // Local Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Find in playlist...", text: $localSearchText)
                        .foregroundColor(.white)
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                    
                    if !localSearchText.isEmpty {
                        Button(action: {
                            localSearchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.vertical, 10)
                
                if !filteredItems.isEmpty {
                    // Action Buttons: Play & Shuffle
                    HStack(spacing: 20) {
                        Button(action: {
                            audioManager.isShuffled = false
                            let songs = playlist.items?.map { $0.song } ?? []
                            if !songs.isEmpty {
                                audioManager.play(song: songs[0], in: songs, at: 0)
                                showFullScreenPlayer = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Play")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.spiderNeonRed)
                            .cornerRadius(25)
                        }
                        .buttonStyle(SpiderButtonStyle())
                        
                        Button(action: {
                            audioManager.isShuffled = true
                            let songs = playlist.items?.map { $0.song } ?? []
                            if let randomSong = songs.randomElement() {
                                audioManager.play(song: randomSong, in: songs, at: 0)
                                showFullScreenPlayer = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "shuffle")
                                Text("Shuffle")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.spiderDarkGrey)
                            .cornerRadius(25)
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Theme.spiderNeonRed.opacity(0.5), lineWidth: 1)
                            )
                        }
                        .buttonStyle(SpiderButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)

                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredItems.indices, id: \.self) { index in
                                let item = filteredItems[index]
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
                                    let songs = filteredItems.map { $0.song }
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
