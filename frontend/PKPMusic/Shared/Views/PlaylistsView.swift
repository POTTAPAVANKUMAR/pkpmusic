import SwiftUI

struct PlaylistsView: View {
    @StateObject private var networkManager = NetworkManager.shared
    @State private var showingCreateAlert = false
    @State private var newPlaylistName = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.SpiderBackground()
                
                VStack {
                    HStack {
                        Text("Playlists")
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: {
                            showingCreateAlert = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                                .foregroundColor(Theme.spiderNeonRed)
                        }
                    }
                    .padding()
                    
                    if networkManager.playlists.isEmpty {
                        Spacer()
                        VStack(spacing: 20) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 60))
                                .foregroundColor(Theme.spiderRed)
                            
                            Text("No Playlists Yet")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Create a playlist using the + button above, or import one via your Raspberry Pi.")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.gray)
                                .padding()
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(networkManager.playlists, id: \.id) { playlist in
                                    NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                                        HStack(spacing: 15) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Theme.spiderDarkGrey)
                                                    .frame(width: 60, height: 60)
                                                Image(systemName: "music.note.list")
                                                    .foregroundColor(Theme.spiderRed)
                                                    .font(.title2)
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(playlist.name)
                                                    .font(.headline)
                                                    .foregroundColor(.white)
                                                Text("\(playlist.items?.count ?? 0) songs")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }
                                            
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.gray)
                                        }
                                        .padding(10)
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Theme.spiderDarkGrey, lineWidth: 1)
                                        )
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            .padding(.top)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                networkManager.fetchPlaylists()
            }
            .alert("Create Playlist", isPresented: $showingCreateAlert) {
                TextField("Playlist Name", text: $newPlaylistName)
                Button("Cancel", role: .cancel) {
                    newPlaylistName = ""
                }
                Button("Create") {
                    if !newPlaylistName.isEmpty {
                        networkManager.createPlaylist(name: newPlaylistName)
                        newPlaylistName = ""
                    }
                }
            }
        }
    }
}
