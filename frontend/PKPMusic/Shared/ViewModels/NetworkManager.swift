import Foundation

class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    // Cloudflare Tunnel URL for your Raspberry Pi
    private let baseURL = "https://pkpmusic.pottapk.win" 
    
    @Published var songs: [Song] = []
    @Published var searchResults: [Song] = []
    @Published var favorites: [Song] = []
    @Published var playlists: [Playlist] = []
    @Published var dashboardSections: [DashboardSection] = []
    @Published var isLoading: Bool = false
    
    // Add dummy auth user for now
    let userId = 1
    
    func fetchDashboard() {
        guard let url = URL(string: "\(baseURL)/dashboard/?user_id=\(userId)") else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                do {
                    let decodedSections = try JSONDecoder().decode([DashboardSection].self, from: data)
                    DispatchQueue.main.async {
                        self.dashboardSections = decodedSections
                    }
                } catch {
                    print("Error decoding dashboard: \(error)")
                }
            }
        }.resume()
    }
    
    func fetchSongs() {
        // Now fetching from history to simulate Home View
        guard let url = URL(string: "\(baseURL)/history/?user_id=\(userId)") else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                do {
                    struct HistoryItem: Codable {
                        let song: Song
                    }
                    let decodedHistory = try JSONDecoder().decode([HistoryItem].self, from: data)
                    DispatchQueue.main.async {
                        self.songs = decodedHistory.map { $0.song }
                    }
                } catch {
                    print("Error decoding history: \(error)")
                }
            }
        }.resume()
    }
    
    func fetchFavorites() {
        guard let url = URL(string: "\(baseURL)/favorites/?user_id=\(userId)") else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                do {
                    struct FavoriteItem: Codable {
                        let song: Song
                    }
                    let decodedFavorites = try JSONDecoder().decode([FavoriteItem].self, from: data)
                    DispatchQueue.main.async {
                        self.favorites = decodedFavorites.map { $0.song }
                    }
                } catch {
                    print("Error decoding favorites: \(error)")
                }
            }
        }.resume()
    }
    
    func fetchPlaylists() {
        guard let url = URL(string: "\(baseURL)/playlists/?user_id=\(userId)") else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                do {
                    let decodedPlaylists = try JSONDecoder().decode([Playlist].self, from: data)
                    DispatchQueue.main.async {
                        self.playlists = decodedPlaylists
                    }
                } catch {
                    print("Error decoding playlists: \(error)")
                }
            }
        }.resume()
    }
    
    func createPlaylist(name: String) {
        guard let url = URL(string: "\(baseURL)/playlists/?user_id=\(userId)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["name": name]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if error == nil {
                self.fetchPlaylists()
            }
        }.resume()
    }
    
    func addSongToPlaylist(songId: String, playlistId: Int) {
        guard let url = URL(string: "\(baseURL)/playlists/\(playlistId)/items") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["song_id": songId, "position": 0]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if error == nil {
                self.fetchPlaylists() // Refresh to get updated items
            }
        }.resume()
    }
    
    func searchYouTube(query: String) {
        guard let escapedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/search/yt?query=\(escapedQuery)") else { return }
              
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
            }
            if let data = data {
                do {
                    let results = try JSONDecoder().decode([Song].self, from: data)
                    DispatchQueue.main.async {
                        self.searchResults = results
                    }
                } catch {
                    print("Error decoding search results: \(error)")
                }
            }
        }.resume()
    }
    
    func recordHistory(songId: String) {
        guard let url = URL(string: "\(baseURL)/history/?user_id=\(userId)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: Date())
        let body: [String: Any] = ["song_id": songId, "played_at": timestamp]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request).resume()
    }
    
    func addToFavorites(songId: String) {
        guard let url = URL(string: "\(baseURL)/favorites/?user_id=\(userId)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["song_id": songId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if error == nil {
                self.fetchFavorites() // Refresh
            }
        }.resume()
    }
    
    func getStreamURL(for songId: String) -> URL? {
        return URL(string: "\(baseURL)/stream/yt/\(songId)")
    }
    
    // MARK: - New Features
    
    func fetchSearchSuggestions(query: String, completion: @escaping ([String]) -> Void) {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/search/suggestions?query=\(encodedQuery)") else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let suggestions = try? JSONDecoder().decode([String].self, from: data) {
                DispatchQueue.main.async { completion(suggestions) }
            }
        }.resume()
    }
    
    func fetchLyrics(videoId: String, completion: @escaping (LyricsResponse?) -> Void) {
        guard let url = URL(string: "\(baseURL)/lyrics/\(videoId)") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let lyrics = try? JSONDecoder().decode(LyricsResponse.self, from: data) {
                DispatchQueue.main.async { completion(lyrics) }
            } else {
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
    }
    
    func fetchArtist(channelId: String, completion: @escaping (ArtistDetail?) -> Void) {
        guard let url = URL(string: "\(baseURL)/artist/\(channelId)") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data {
                do {
                    let artist = try JSONDecoder().decode(ArtistDetail.self, from: data)
                    DispatchQueue.main.async { completion(artist) }
                } catch {
                    print("Error decoding artist: \(error)")
                    DispatchQueue.main.async { completion(nil) }
                }
            }
        }.resume()
    }
    
    func fetchAlbum(browseId: String, completion: @escaping (AlbumDetail?) -> Void) {
        guard let url = URL(string: "\(baseURL)/album/\(browseId)") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data {
                do {
                    let album = try JSONDecoder().decode(AlbumDetail.self, from: data)
                    DispatchQueue.main.async { completion(album) }
                } catch {
                    print("Error decoding album: \(error)")
                    DispatchQueue.main.async { completion(nil) }
                }
            }
        }.resume()
    }
    
    func fetchMoodPlaylists(params: String, completion: @escaping ([DashboardItem]) -> Void) {
        guard let url = URL(string: "\(baseURL)/moods/\(params)") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let items = try? JSONDecoder().decode([DashboardItem].self, from: data) {
                DispatchQueue.main.async { completion(items) }
            } else {
                DispatchQueue.main.async { completion([]) }
            }
        }.resume()
    }
}
