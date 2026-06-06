import SwiftUI

struct PlaylistsView: View {
    @State private var showingCreateAlert = false
    @State private var newPlaylistName = ""
    @State private var playlists: [String] = [] // Placeholder for real playlists
    
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
                    
                    if playlists.isEmpty {
                        Spacer()
                        VStack(spacing: 20) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 60))
                                .foregroundColor(Theme.spiderRed)
                            
                            Text("No Playlists Yet")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("To import a playlist from Amazon Music, export it as a CSV and upload it to the /playlists/import/csv endpoint on your Raspberry Pi.")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.gray)
                                .padding()
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(playlists, id: \.self) { playlist in
                                    HStack(spacing: 15) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Theme.spiderDarkGrey)
                                                .frame(width: 60, height: 60)
                                            Image(systemName: "music.note.list")
                                                .foregroundColor(Theme.spiderRed)
                                                .font(.title2)
                                        }
                                        
                                        Text(playlist)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
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
                            .padding(.top)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
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
