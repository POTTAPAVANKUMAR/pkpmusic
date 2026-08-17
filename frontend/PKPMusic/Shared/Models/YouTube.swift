import Foundation

struct LyricsResponse: Codable {
    let lyrics: String
    let source: String
}

struct Thumbnail: Codable {
    let url: String
    let width: Int
    let height: Int
}

struct AlbumRef: Codable {
    let title: String
    let browseId: String
    let thumbnails: [Thumbnail]?
}

struct ArtistDetail: Codable {
    let name: String
    let description: String?
    let views: String?
    let subscribers: String?
    let thumbnails: [Thumbnail]
    let songs: [Song]
    let albums: [AlbumRef]?
}

struct AlbumDetail: Codable {
    let title: String
    let description: String?
    let trackCount: Int
    let thumbnails: [Thumbnail]
    let songs: [Song]
}
