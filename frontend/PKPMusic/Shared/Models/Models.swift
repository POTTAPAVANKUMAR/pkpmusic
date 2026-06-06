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

struct Playlist: Identifiable, Codable {
    let id: Int
    let name: String
    let description: String?
    let items: [PlaylistItem]?
}

struct PlaylistItem: Identifiable, Codable {
    let id: Int
    let playlistId: Int
    let song: Song
    
    enum CodingKeys: String, CodingKey {
        case id
        case playlistId = "playlist_id"
        case song
    }
}

struct DashboardItem: Identifiable, Codable {
    let id: String
    let title: String
    let subtitle: String?
    let imageUrl: String?
    let type: String // "song", "playlist", "mood"
    
    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, type
        case imageUrl = "image_url"
    }
}

struct DashboardSection: Codable {
    let title: String
    let items: [DashboardItem]
}
