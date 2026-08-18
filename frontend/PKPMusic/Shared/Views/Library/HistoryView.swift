import SwiftUI

struct HistoryView: View {
    @StateObject private var networkManager = NetworkManager.shared
    @StateObject private var audioManager = AudioPlayerManager.shared
    @State private var showFullScreenPlayer = false
    @State private var searchText = ""
    
    var filteredSongs: [Song] {
        if searchText.isEmpty {
            return networkManager.historySongs
        }
        return networkManager.historySongs.filter {
            $0.title.lowercased().contains(searchText.lowercased()) ||
            $0.artist.lowercased().contains(searchText.lowercased())
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.SpiderBackground()
                
                VStack(spacing: 0) {
                    // Top Header Bar
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Listening History")
                                .font(.largeTitle)
                                .bold()
                                .foregroundColor(.white)
                            
                            if !networkManager.historySongs.isEmpty {
                                Text("\(networkManager.historySongs.count) songs played")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Spacer()
                        
                        if !networkManager.historySongs.isEmpty {
                            HStack(spacing: 10) {
                                // Shuffle Button
                                Button(action: {
                                    if let random = networkManager.historySongs.randomElement() {
                                        audioManager.isShuffled = true
                                        audioManager.play(song: random, in: networkManager.historySongs, at: 0)
                                        showFullScreenPlayer = true
                                    }
                                }) {
                                    Image(systemName: "shuffle")
                                        .font(.headline)
                                        .foregroundColor(Theme.spiderNeonRed)
                                        .padding(10)
                                        .background(Theme.spiderNeonRed.opacity(0.15))
                                        .clipShape(Circle())
                                }
                                
                                // Play All Button
                                Button(action: {
                                    if let first = networkManager.historySongs.first {
                                        audioManager.isShuffled = false
                                        audioManager.play(song: first, in: networkManager.historySongs, at: 0)
                                        showFullScreenPlayer = true
                                    }
                                }) {
                                    Image(systemName: "play.fill")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(10)
                                        .background(Theme.spiderNeonRed)
                                        .clipShape(Circle())
                                        .shadow(color: Theme.spiderNeonRed.opacity(0.4), radius: 6, x: 0, y: 3)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                    
                    // Search Bar
                    if !networkManager.historySongs.isEmpty || !searchText.isEmpty {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            TextField("Search history...", text: $searchText)
                                .foregroundColor(.white)
                                .disableAutocorrection(true)
                                .autocapitalization(.none)
                            
                            if !searchText.isEmpty {
                                Button(action: {
                                    searchText = ""
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
                        .padding(.bottom, 10)
                    }
                    
                    // History List
                    if networkManager.isHistoryLoading && networkManager.historySongs.isEmpty {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.spiderNeonRed))
                            .scaleEffect(1.5)
                        Spacer()
                    } else if filteredSongs.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 60))
                                .foregroundColor(Theme.spiderNeonRed.opacity(0.8))
                            
                            Text(searchText.isEmpty ? "No History Yet" : "No Results Found")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.white)
                            
                            Text(searchText.isEmpty ? "Songs you listen to will automatically be recorded here." : "Try searching for a different song or artist.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(filteredSongs.indices, id: \.self) { index in
                                    let song = filteredSongs[index]
                                    SongRowView(song: song, isPlaying: audioManager.currentSong?.id == song.id)
                                        .onTapGesture {
                                            audioManager.play(song: song, in: filteredSongs, at: index)
                                            showFullScreenPlayer = true
                                        }
                                        .padding(.horizontal)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                networkManager.fetchHistory()
            }
            .fullScreenCover(isPresented: $showFullScreenPlayer) {
                FullScreenPlayerView(isShowing: $showFullScreenPlayer)
            }
        }
    }
}
