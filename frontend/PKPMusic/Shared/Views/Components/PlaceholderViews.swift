import SwiftUI


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
