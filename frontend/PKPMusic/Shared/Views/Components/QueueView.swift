import SwiftUI

struct QueueView: View {
    @ObservedObject var audioManager = AudioPlayerManager.shared
    @Binding var isShowing: Bool
    @State private var selectedAlbumSong: Song? = nil
    
    var upcomingSongs: [(index: Int, song: Song)] {
        guard !audioManager.queue.isEmpty else { return [] }
        let nextIndex = audioManager.currentIndex + 1
        guard nextIndex < audioManager.queue.count else { return [] }
        return Array(audioManager.queue.enumerated())[nextIndex..<audioManager.queue.count].map { ($0.offset, $0.element) }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.spiderDarkGrey.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Section 1: Now Playing
                        if let currentSong = audioManager.currentSong {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("NOW PLAYING")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                                    .tracking(1)
                                
                                HStack(spacing: 14) {
                                    AsyncImage(url: URL(string: currentSong.coverArtUrl ?? "")) { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        ZStack {
                                            Theme.spiderDarkGrey
                                            Image(systemName: "music.note")
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .frame(width: 54, height: 54)
                                    .cornerRadius(8)
                                    .shadow(color: Theme.spiderNeonRed.opacity(0.4), radius: 6, x: 0, y: 0)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(currentSong.title)
                                            .font(.headline)
                                            .foregroundColor(Theme.spiderNeonRed)
                                            .lineLimit(1)
                                        Text(currentSong.artist)
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                    
                                    if audioManager.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.spiderNeonRed))
                                            .scaleEffect(0.9)
                                    } else if audioManager.isPlaying {
                                        Image(systemName: "waveform")
                                            .font(.title3)
                                            .foregroundColor(Theme.spiderNeonRed)
                                    }
                                }
                                .padding(12)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Theme.spiderNeonRed.opacity(0.6), lineWidth: 1)
                                )
                                .contextMenu {
                                    Button(action: {
                                        selectedAlbumSong = currentSong
                                    }) {
                                        Label("Go to Album", systemImage: "opticaldisc")
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 15)
                        }
                        
                        // Section 2: Up Next List
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("NEXT IN QUEUE")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                                    .tracking(1)
                                
                                Spacer()
                                
                                Button(action: {
                                    audioManager.isAutoPlayEnabled.toggle()
                                }) {
                                    HStack(spacing: 5) {
                                        Image(systemName: "infinity")
                                        Text("Autoplay")
                                    }
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(audioManager.isAutoPlayEnabled ? Theme.spiderNeonRed : .gray)
                                }
                            }
                            
                            if upcomingSongs.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "text.badge.plus")
                                        .font(.system(size: 36))
                                        .foregroundColor(.gray.opacity(0.5))
                                    Text("No songs in queue")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                    Text("Tap 'Play Next' or 'Add to Queue' on any track to add it here.")
                                        .font(.caption)
                                        .foregroundColor(.gray.opacity(0.8))
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                                .background(Color.white.opacity(0.03))
                                .cornerRadius(12)
                            } else {
                                ForEach(upcomingSongs, id: \.index) { item in
                                    let actualIndex = item.index
                                    let song = item.song
                                    
                                    HStack(spacing: 12) {
                                        Text("\(actualIndex - audioManager.currentIndex)")
                                            .font(.caption)
                                            .bold()
                                            .foregroundColor(.gray)
                                            .frame(width: 20)
                                        
                                        AsyncImage(url: URL(string: song.coverArtUrl ?? "")) { image in
                                            image.resizable().aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            ZStack {
                                                Theme.spiderDarkGrey
                                                Image(systemName: "music.note")
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        .frame(width: 46, height: 46)
                                        .cornerRadius(6)
                                        
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(song.title)
                                                .font(.subheadline)
                                                .bold()
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                            Text(song.artist)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                                .lineLimit(1)
                                        }
                                        
                                        Spacer()
                                        
                                        // Remove from queue button
                                        Button(action: {
                                            withAnimation(.spring()) {
                                                audioManager.removeFromQueue(at: actualIndex)
                                            }
                                        }) {
                                            Image(systemName: "trash")
                                                .font(.caption)
                                                .foregroundColor(.gray.opacity(0.7))
                                                .padding(8)
                                        }
                                    }
                                    .padding(10)
                                    .background(Color.white.opacity(0.04))
                                    .cornerRadius(10)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        audioManager.playSongInQueue(at: actualIndex)
                                    }
                                    .contextMenu {
                                        Button(action: {
                                            selectedAlbumSong = song
                                        }) {
                                            Label("Go to Album", systemImage: "opticaldisc")
                                        }
                                        
                                        Button(action: {
                                            withAnimation(.spring()) {
                                                audioManager.removeFromQueue(at: actualIndex)
                                            }
                                        }) {
                                            Label("Remove from Queue", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedAlbumSong) { song in
                NavigationView {
                    AlbumDetailView(albumId: song.albumId ?? "", song: song)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    selectedAlbumSong = nil
                                }
                                .foregroundColor(Theme.spiderNeonRed)
                            }
                        }
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack {
                        Text("PLAYING QUEUE")
                            .font(.caption)
                            .bold()
                            .foregroundColor(Theme.spiderNeonRed)
                        Text("Up Next (\(upcomingSongs.count))")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isShowing = false
                    }
                    .foregroundColor(Theme.spiderNeonRed)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if !upcomingSongs.isEmpty {
                        Button("Clear") {
                            withAnimation(.spring()) {
                                audioManager.clearUpcomingQueue()
                            }
                        }
                        .foregroundColor(Theme.spiderNeonRed)
                    }
                }
            }
        }
    }

