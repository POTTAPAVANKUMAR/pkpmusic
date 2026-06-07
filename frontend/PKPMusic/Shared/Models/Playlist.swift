import Foundation

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
