import SwiftUI

struct LocalAlbumDetailView: View {
    let albumName: String
    let songs: [Song]
    @StateObject private var audioManager = AudioPlayerManager.shared
    @State private var showFullScreenPlayer = false
    
    @State private var searchText = ""
    
    private var filteredSongs: [Song] {
        if searchText.isEmpty { return songs }
        return songs.filter { song in
            song.title.localizedCaseInsensitiveContains(searchText) ||
            song.artist.localizedCaseInsensitiveContains(searchText)
        }
    }
    
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
                    
                    // Action Buttons: Play & Shuffle
                    if !songs.isEmpty {
                        HStack(spacing: 20) {
                            Button(action: {
                                audioManager.isShuffled = false
                                audioManager.play(song: songs[0], in: songs, at: 0)
                                showFullScreenPlayer = true
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
                                let randomSong = songs.randomElement() ?? songs[0]
                                audioManager.play(song: randomSong, in: songs, at: 0)
                                showFullScreenPlayer = true
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
                    }
                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search in album...", text: $searchText)
                            .foregroundColor(.white)
                            .disableAutocorrection(true)
                            .autocapitalization(.none)
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(12)
                    .background(Theme.spiderDarkGrey.opacity(0.6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    // Songs
                    if !filteredSongs.isEmpty {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredSongs.indices, id: \.self) { index in
                                let song = filteredSongs[index]
                                SongRowView(song: song, isPlaying: audioManager.currentSong?.id == song.id)
                                    .onTapGesture {
                                        audioManager.play(song: song, in: filteredSongs, at: index)
                                        showFullScreenPlayer = true
                                    }
                            }
                        }
                        .padding()
                    } else if !songs.isEmpty {
                        Text("No songs match your search.")
                            .foregroundColor(.gray)
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

struct LocalArtistDetailView: View {
    let artistName: String
    let songs: [Song]
    @StateObject private var audioManager = AudioPlayerManager.shared
    @State private var showFullScreenPlayer = false
    
    @State private var searchText = ""
    
    private var filteredSongs: [Song] {
        if searchText.isEmpty { return songs }
        return songs.filter { song in
            song.title.localizedCaseInsensitiveContains(searchText) ||
            song.album?.localizedCaseInsensitiveContains(searchText) ?? false
        }
    }
    
    var body: some View {
        ZStack {
            Theme.SpiderBackground()
            
            ScrollView {
                VStack(alignment: .center, spacing: 20) {
                    // Header
                    ZStack {
                        Circle()
                            .fill(Theme.spiderDarkGrey)
                        
                        if let firstSongArt = songs.first?.coverArtUrl, let url = URL(string: firstSongArt) {
                            AsyncImage(url: url) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "person.fill").font(.system(size: 80)).foregroundColor(Theme.spiderNeonRed)
                            }
                            .frame(width: 250, height: 250)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 80))
                                .foregroundColor(Theme.spiderNeonRed)
                        }
                    }
                    .frame(width: 250, height: 250)
                    .shadow(color: Theme.spiderNeonRed.opacity(0.3), radius: 20)
                    .padding(.top, 20)
                    
                    VStack(spacing: 8) {
                        Text(artistName)
                            .font(.title)
                            .bold()
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Text("\(songs.count) tracks")
                            .font(.caption)
                            .foregroundColor(Theme.spiderRed)
                    }
                    
                    // Action Buttons: Play & Shuffle
                    if !songs.isEmpty {
                        HStack(spacing: 20) {
                            Button(action: {
                                audioManager.isShuffled = false
                                audioManager.play(song: songs[0], in: songs, at: 0)
                                showFullScreenPlayer = true
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
                                let randomSong = songs.randomElement() ?? songs[0]
                                audioManager.play(song: randomSong, in: songs, at: 0)
                                showFullScreenPlayer = true
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
                    }
                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search tracks...", text: $searchText)
                            .foregroundColor(.white)
                            .disableAutocorrection(true)
                            .autocapitalization(.none)
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(12)
                    .background(Theme.spiderDarkGrey.opacity(0.6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    // Songs
                    if !filteredSongs.isEmpty {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredSongs.indices, id: \.self) { index in
                                let song = filteredSongs[index]
                                SongRowView(song: song, isPlaying: audioManager.currentSong?.id == song.id)
                                    .onTapGesture {
                                        audioManager.play(song: song, in: filteredSongs, at: index)
                                        showFullScreenPlayer = true
                                    }
                            }
                        }
                        .padding()
                    } else if !songs.isEmpty {
                        Text("No songs match your search.")
                            .foregroundColor(.gray)
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
