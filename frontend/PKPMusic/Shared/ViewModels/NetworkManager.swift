import Foundation

class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    // Cloudflare Tunnel URL for your Raspberry Pi
    private let baseURL = "https://pkpmusic.pottapk.win" 
    
    @Published var songs: [Song] = []
    @Published var searchResults: [Song] = []
    
    // Add dummy auth user for now
    let userId = 1
    
    func fetchSongs() {
        // Now fetching from history to simulate Home View
        guard let url = URL(string: "\(baseURL)/history/?user_id=\(userId)") else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                do {
                    // Quick map from History back to Songs
                    // Assuming History struct returns the embedded Song
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
    
    func searchYouTube(query: String) {
        guard let escapedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/search/yt?query=\(escapedQuery)") else { return }
              
        URLSession.shared.dataTask(with: url) { data, response, error in
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
        
        // Simple ISO timestamp for played_at
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: Date())
        
        let body: [String: Any] = ["song_id": songId, "played_at": timestamp]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request).resume()
    }
    
    func getStreamURL(for songId: String) -> URL? {
        return URL(string: "\(baseURL)/stream/yt/\(songId)")
    }
}
