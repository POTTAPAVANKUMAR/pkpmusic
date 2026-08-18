import SwiftUI

struct ExploreView: View {
    @StateObject private var networkManager = NetworkManager.shared
    @State private var exploreSections: [DashboardSection] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ZStack {
                ThemeManager.shared.currentTheme.backgroundColor.edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Theme.neonAccent))
                                .frame(maxWidth: .infinity, minHeight: 200)
                        } else if !exploreSections.isEmpty {
                            ForEach(exploreSections) { section in
                                DashboardSectionView(section: section)
                            }
                        } else {
                            Text("Failed to load explore data.")
                                .foregroundColor(.secondary)
                                .padding()
                        }
                    }
                    .padding(.vertical)
                }
                .navigationTitle("Explore")
            }
            .onAppear {
                if exploreSections.isEmpty && !isLoading {
                    isLoading = true
                    networkManager.fetchExplore { sections in
                        self.exploreSections = sections
                        self.isLoading = false
                    }
                }
            }
        }
    }
}
