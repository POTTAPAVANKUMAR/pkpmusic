import SwiftUI

struct ArtistDetailView: View {
    let artistId: String
    let artistName: String
    
    @StateObject private var networkManager = NetworkManager.shared
    @StateObject private var audioManager = AudioPlayerManager.shared
    
    @State private var artistDetail: ArtistDetail?
    @State private var isLoading = true
    @State private var showFullScreenPlayer = false
    
    @State private var searchText = ""
    
    private var filteredSongs: [Song] {
        guard let detail = artistDetail else { return [] }
        if searchText.isEmpty { return detail.songs }
        return detail.songs.filter { song in
            song.title.localizedCaseInsensitiveContains(searchText) ||
            song.album?.localizedCaseInsensitiveContains(searchText) == true
        }
    }
    
    var body: some View {
        ZStack {
            Theme.SpiderBackground()
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.spiderNeonRed))
                    .scaleEffect(1.5)
            } else if let detail = artistDetail {
                ScrollView {
                    VStack(alignment: .center, spacing: 20) {
                        // Header
                        if let headerUrl = detail.thumbnails.last?.url, let url = URL(string: headerUrl) {
                            AsyncImage(url: url) { image in
                                image.resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle().fill(Theme.spiderDarkGrey)
                            }
                            .frame(width: 250, height: 250)
                            .cornerRadius(15)
                            .shadow(color: Theme.spiderNeonRed.opacity(0.3), radius: 20)
                            .padding(.top, 20)
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .foregroundColor(Theme.spiderDarkGrey)
                                .frame(width: 250, height: 250)
                                .cornerRadius(15)
                                .shadow(color: Theme.spiderNeonRed.opacity(0.3), radius: 20)
                                .padding(.top, 20)
                        }
                        
                        VStack(spacing: 8) {
                            HStack {
                                Text(detail.name)
                                    .font(.title)
                                    .bold()
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                
                                Button(action: {
                                    networkManager.addBookmark(itemId: artistId, itemType: "artist", title: detail.name, coverArtUrl: detail.thumbnails.last?.url)
                                }) {
                                    Image(systemName: "bookmark")
                                        .font(.title2)
                                        .foregroundColor(Theme.spiderNeonRed)
                                }
                            }
                            
                            if let desc = detail.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                    .lineLimit(3)
                            }
                            
                            if let subs = detail.subscribers {
                                Text("\(subs) subscribers")
                                    .font(.caption)
                                    .foregroundColor(Theme.spiderRed)
                            }
                        }
                        
                        // Action Buttons: Play & Shuffle
                        if !detail.songs.isEmpty {
                            HStack(spacing: 20) {
                                Button(action: {
                                    audioManager.isShuffled = false
                                    audioManager.play(song: detail.songs[0], in: detail.songs, at: 0)
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
                                    let randomSong = detail.songs.randomElement() ?? detail.songs[0]
                                    audioManager.play(song: randomSong, in: detail.songs, at: 0)
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
                            TextField("Search top songs...", text: $searchText)
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
                                            networkManager.recordHistory(songId: song.id)
                                        }
                                }
                            }
                            .padding()
                        } else if !detail.songs.isEmpty {
                            Text("No songs match your search.")
                                .foregroundColor(.gray)
                                .padding()
                        }
                        
                        // Albums section
                        if let albums = detail.albums, !albums.isEmpty {
                            VStack(alignment: .leading) {
                                HStack {
                                    Text("Albums")
                                        .font(.title2)
                                        .bold()
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    NavigationLink(destination: ArtistAlbumsView(artistId: artistId, artistName: detail.name)) {
                                        Text("See All")
                                            .font(.subheadline)
                                            .foregroundColor(Theme.spiderRed)
                                    }
                                }
                                .padding(.horizontal)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(albums, id: \.browseId) { album in
                                            NavigationLink(destination: AlbumDetailView(albumId: album.browseId)) {
                                                VStack(alignment: .leading) {
                                                    if let urlString = album.thumbnails?.last?.url,
                                                       let url = URL(string: urlString) {
                                                        AsyncImage(url: url) { image in
                                                            image.resizable().aspectRatio(contentMode: .fill)
                                                        } placeholder: {
                                                            Theme.spiderDarkGrey
                                                        }
                                                        .frame(width: 150, height: 150)
                                                        .cornerRadius(12)
                                                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
                                                    } else {
                                                        Theme.spiderDarkGrey
                                                            .frame(width: 150, height: 150)
                                                            .cornerRadius(12)
                                                    }
                                                    
                                                    Text(album.title)
                                                        .font(.subheadline)
                                                        .foregroundColor(.white)
                                                        .lineLimit(1)
                                                        .frame(width: 150, alignment: .leading)
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.bottom, 30)
                        }
                    }
                }
            } else {
                Text("Failed to load artist.")
                    .foregroundColor(.gray)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            networkManager.fetchArtist(channelId: artistId) { detail in
                self.artistDetail = detail
                self.isLoading = false
            }
        }
        .fullScreenCover(isPresented: $showFullScreenPlayer) {
            FullScreenPlayerView(isShowing: $showFullScreenPlayer)
        }
    }
}
