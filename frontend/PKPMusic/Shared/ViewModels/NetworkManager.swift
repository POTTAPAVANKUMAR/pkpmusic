import Foundation

class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    // Cloudflare Tunnel URL for your Raspberry Pi
    let baseURL = "https://pkpmusic.pottapk.win" 
    
    @Published var songs: [Song] = []
    @Published var searchResults: [Song] = []
    @Published var favorites: [Song] = []
    @Published var playlists: [Playlist] = []
    @Published var dashboardSections: [DashboardSection] = []
    @Published var dashboardError: String?
    @Published var isLoading: Bool = false
    
    private func createRequest(for urlString: String, method: String = "GET") -> URLRequest? {
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let token = AuthManager.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
    
    func fetchDashboard() {
        guard let request = createRequest(for: "\(baseURL)/dashboard/") else { return }
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error fetching dashboard: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    if self.dashboardSections.isEmpty && !DownloadManager.shared.downloadedSongs.isEmpty {
                        let offlineItems = DownloadManager.shared.downloadedSongs.map { DashboardItem(id: $0.id, title: $0.title, subtitle: $0.artist, imageUrl: $0.coverArtUrl, type: "song") }
                        let offlineSection = DashboardSection(title: "Available Offline", items: offlineItems)
                        self.dashboardSections = [offlineSection]
                    }
                }
                return
            }
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
        guard let request = createRequest(for: "\(baseURL)/history/") else { return }
        URLSession.shared.dataTask(with: request) { data, response, error in
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
        guard let request = createRequest(for: "\(baseURL)/favorites/") else { return }
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error fetching favorites: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    if self.favorites.isEmpty {
                        self.favorites = DownloadManager.shared.downloadedSongs
                    }
                }
                return
            }
            if let data = data {
                do {
                    struct FavoriteItem: Codable {
                        let song: Song
                    }
                    let decodedFavorites = try JSONDecoder().decode([FavoriteItem].self, from: data)
                    DispatchQueue.main.async {
                        let favSongs = decodedFavorites.map { $0.song }
                        self.favorites = favSongs
                        
                        // Automatically download favorite songs
                        for song in favSongs {
                            if !DownloadManager.shared.isDownloaded(songId: song.id) {
                                DownloadManager.shared.download(song: song)
                            }
                        }
                    }
                } catch {
                    print("Error decoding favorites: \(error)")
                }
            }
        }.resume()
    }
    
    func fetchPlaylists() {
        guard let request = createRequest(for: "\(baseURL)/playlists/") else { return }
        URLSession.shared.dataTask(with: request) { data, response, error in
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
        guard var request = createRequest(for: "\(baseURL)/playlists/", method: "POST") else { return }
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
        guard var request = createRequest(for: "\(baseURL)/playlists/\(playlistId)/items", method: "POST") else { return }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["song_id": songId, "position": 0]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if error == nil {
                self.fetchPlaylists()
            }
        }.resume()
    }
    
    func searchYouTube(query: String) {
        guard let escapedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let request = createRequest(for: "\(baseURL)/search/yt?query=\(escapedQuery)") else { return }
              
        DispatchQueue.main.async { self.isLoading = true }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async { self.isLoading = false }
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
        guard var request = createRequest(for: "\(baseURL)/history/", method: "POST") else { return }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: Date())
        let body: [String: Any] = ["song_id": songId, "played_at": timestamp]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request).resume()
    }
    
    func addToFavorites(songId: String) {
        guard var request = createRequest(for: "\(baseURL)/favorites/", method: "POST") else { return }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["song_id": songId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if error == nil {
                self.fetchFavorites()
            }
        }.resume()
    }
    
    func getStreamURL(for songId: String) -> URL? {
        return URL(string: "\(baseURL)/stream/yt/\(songId)")
    }
    
    func fetchSearchSuggestions(query: String, completion: @escaping ([String]) -> Void) {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let request = createRequest(for: "\(baseURL)/search/suggestions?query=\(encodedQuery)") else { return }
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data, let suggestions = try? JSONDecoder().decode([String].self, from: data) {
                DispatchQueue.main.async { completion(suggestions) }
            }
        }.resume()
    }
    
    func fetchLyrics(videoId: String, completion: @escaping (LyricsResponse?) -> Void) {
        guard let request = createRequest(for: "\(baseURL)/lyrics/\(videoId)") else { return }
        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data, let lyrics = try? JSONDecoder().decode(LyricsResponse.self, from: data) {
                DispatchQueue.main.async { completion(lyrics) }
            } else {
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
    }
    
    func fetchArtist(channelId: String, completion: @escaping (ArtistDetail?) -> Void) {
        guard let request = createRequest(for: "\(baseURL)/artist/\(channelId)") else { return }
        URLSession.shared.dataTask(with: request) { data, _, _ in
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
        guard let request = createRequest(for: "\(baseURL)/album/\(browseId)") else { return }
        URLSession.shared.dataTask(with: request) { data, _, _ in
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
        guard let request = createRequest(for: "\(baseURL)/moods/\(params)") else { return }
        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data, let items = try? JSONDecoder().decode([DashboardItem].self, from: data) {
                DispatchQueue.main.async { completion(items) }
            } else {
                DispatchQueue.main.async { completion([]) }
            }
        }.resume()
    }
    
    func uploadCSV(fileURL: URL, completion: @escaping (Bool) -> Void) {
        guard var request = createRequest(for: "\(baseURL)/playlists/import/csv", method: "POST") else { return }
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        guard let fileData = try? Data(contentsOf: fileURL) else {
            completion(false)
            return
        }
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"import.csv\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: text/csv\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                completion(error == nil)
            }
        }.resume()
    }
}
