import SwiftUI

struct ExploreView: View {
    @StateObject private var networkManager = NetworkManager.shared
    @State private var exploreSections: [DashboardSection] = []
    @State private var isLoading = false
    @State private var selectedMoodCategory: String? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                ThemeManager.shared.currentTheme.backgroundColor.edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // Clean Explore Header
                        VStack(alignment: .leading, spacing: 6) {
                            Text("EXPLORE & DISCOVER")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Theme.neonAccent)
                                .tracking(1.5)
                            
                            Text("World of Music")
                                .font(.system(size: 28, weight: .black))
                                .foregroundColor(.white)
                            
                            Text("Trending releases, global charts, and soundscapes.")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                        // Genre / Mood Pills
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                let moods = [
                                    ("Workout", "figure.run", "Workout"),
                                    ("Chill", "wind", "Chill"),
                                    ("Party", "party.popper.fill", "Party"),
                                    ("Focus", "brain.head.profile", "Focus"),
                                    ("Romance", "heart.fill", "Romance"),
                                    ("Feel Good", "sun.max.fill", "Feel Good"),
                                    ("Gaming", "gamecontroller.fill", "Gaming")
                                ]
                                
                                ForEach(0..<moods.count, id: \.self) { i in
                                    NavigationLink(destination: MoodPlaylistsView(params: moods[i].2, moodTitle: moods[i].0)) {
                                        HStack(spacing: 6) {
                                            Image(systemName: moods[i].1)
                                                .font(.system(size: 12))
                                            Text(moods[i].0)
                                                .font(.system(size: 13, weight: .bold))
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Color.white.opacity(0.08))
                                        .foregroundColor(.white)
                                        .cornerRadius(18)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18)
                                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Content Sections
                        if isLoading {
                            ProgressView("Discovering music...")
                                .progressViewStyle(CircularProgressViewStyle(tint: Theme.neonAccent))
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, minHeight: 200)
                        } else if !exploreSections.isEmpty {
                            VStack(spacing: 28) {
                                ForEach(exploreSections) { section in
                                    DashboardSectionView(section: section)
                                }
                            }
                        } else {
                            VStack(spacing: 12) {
                                Text("No explore items found")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Button("Refresh") {
                                    loadExplore()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Theme.spiderNeonRed)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .frame(maxWidth: .infinity, minHeight: 200)
                        }
                    }
                    .padding(.bottom, 100)
                }
                .refreshable {
                    loadExplore()
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                if exploreSections.isEmpty && !isLoading {
                    loadExplore()
                }
            }
        }
    }
    
    private func loadExplore() {
        isLoading = true
        networkManager.fetchExplore { sections in
            self.exploreSections = sections
            self.isLoading = false
        }
    }
}

