import SwiftUI

struct ExploreView: View {
    @StateObject private var networkManager = NetworkManager.shared
    @State private var exploreData: YTExploreData?
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ZStack {
                ThemeManager.shared.currentTheme.backgroundColor.edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .frame(maxWidth: .infinity, minHeight: 200)
                        } else if exploreData != nil {
                            // Normally we would parse exploreData and show sections
                            Text("Explore Data Loaded (Raw parsing required)")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            Text("Failed to load explore data.")
                                .foregroundColor(.secondary)
                                .padding()
                        }
                    }
                    .padding()
                }
                .navigationTitle("Explore")
            }
            .onAppear {
                if exploreData == nil && !isLoading {
                    isLoading = true
                    networkManager.fetchExplore { data in
                        self.exploreData = data
                        self.isLoading = false
                    }
                }
            }
        }
    }
}
