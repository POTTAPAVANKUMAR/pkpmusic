import SwiftUI

struct LibraryView: View {
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Playlists")) {
                    Text("Favorites")
                    Text("Workout Mix")
                    Text("Chill Vibes")
                }
                
                Section(header: Text("Local Files (Raspberry Pi)")) {
                    Text("All Songs")
                    Text("Artists")
                    Text("Albums")
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Library")
        }
    }
}

struct SearchView: View {
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Search your local library or recommendations")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Artists, Songs, or Playlists")
        }
    }
}
