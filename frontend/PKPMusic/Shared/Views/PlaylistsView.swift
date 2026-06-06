import SwiftUI

struct PlaylistsView: View {
    @State private var showingCreateAlert = false
    @State private var newPlaylistName = ""
    @State private var playlists: [String] = [] // Placeholder for real playlists
    
    var body: some View {
        NavigationView {
            VStack {
                if playlists.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 60))
                            .foregroundColor(.purple)
                        
                        Text("No Playlists Yet")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("To import a playlist from Amazon Music, export it as a CSV and upload it to the /playlists/import/csv endpoint on your Raspberry Pi.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    .padding()
                } else {
                    List {
                        ForEach(playlists, id: \.self) { playlist in
                            HStack {
                                Image(systemName: "music.note.list")
                                    .foregroundColor(.purple)
                                Text(playlist)
                            }
                        }
                    }
                }
                Spacer()
            }
            .navigationTitle("Playlists")
            .toolbar {
                Button(action: {
                    showingCreateAlert = true
                }) {
                    Image(systemName: "plus")
                }
            }
            .alert("Create Playlist", isPresented: $showingCreateAlert) {
                TextField("Playlist Name", text: $newPlaylistName)
                Button("Cancel", role: .cancel) {
                    newPlaylistName = ""
                }
                Button("Create") {
                    if !newPlaylistName.isEmpty {
                        playlists.append(newPlaylistName)
                        newPlaylistName = ""
                    }
                }
            }
        }
    }
}
