import Foundation

struct Song: Identifiable, Codable {
    let id: String
    let title: String
    let artist: String
    let album: String?
    let durationMs: Int?
    let coverArtUrl: String?
    
    // Convert to camelCase from snake_case during decoding
    enum CodingKeys: String, CodingKey {
        case id, title, artist, album
        case durationMs = "duration_ms"
        case coverArtUrl = "cover_art_url"
    }
}
