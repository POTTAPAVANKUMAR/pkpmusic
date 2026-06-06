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

struct LyricsResponse: Codable {
    let lyrics: String
    let source: String
}

struct Thumbnail: Codable {
    let url: String
    let width: Int
    let height: Int
}

struct ArtistDetail: Codable {
    let name: String
    let description: String?
    let views: String?
    let subscribers: String?
    let thumbnails: [Thumbnail]
    let songs: [Song]
    // We can ignore albums for now or add them later
}

struct AlbumDetail: Codable {
    let title: String
    let description: String?
    let trackCount: Int
    let thumbnails: [Thumbnail]
    let songs: [Song]
}
