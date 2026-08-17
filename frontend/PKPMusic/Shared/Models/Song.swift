import Foundation

struct Song: Identifiable, Codable {
    let id: String
    let title: String
    let artist: String
    let album: String?
    let albumId: String?
    let durationMs: Int?
    let coverArtUrl: String?
    
    // Convert to camelCase from snake_case during decoding
    enum CodingKeys: String, CodingKey {
        case id, title, artist, album
        case albumId = "album_id"
        case durationMs = "duration_ms"
        case coverArtUrl = "cover_art_url"
    }
}

struct AlbumSearchResult: Identifiable, Codable {
    let id: String
    let title: String
    let artist: String
    let year: String?
    let coverArtUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "browseId"
        case title, artist, year
        case coverArtUrl = "cover_art_url"
    }
}

struct ArtistSearchResult: Identifiable, Codable {
    let id: String
    let artist: String
    let coverArtUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "browseId"
        case artist
        case coverArtUrl = "cover_art_url"
    }
}
