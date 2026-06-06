import SwiftUI

struct PlaylistsView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)
                
                Text("Playlists")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("To import a playlist from Amazon Music, export it as a CSV (using a tool like TuneMyMusic) and upload it to the /playlists/import/csv endpoint on your Raspberry Pi.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding()
                
                Spacer()
            }
            .padding()
            .navigationTitle("Playlists")
        }
    }
}
