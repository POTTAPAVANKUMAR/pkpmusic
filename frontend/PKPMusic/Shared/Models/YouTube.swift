import Foundation

struct LyricsResponse: Codable {
    let lyrics: String
    let source: String
    let isSynced: Bool?
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

// MARK: - New Models

struct YTRelatedData: Codable {
    let related: [Song]?
}

struct YTExploreData: Codable {
    // Explore data is heavily nested, often just a dictionary in python.
    // We can define a generic container or just use raw data parsing in NetworkManager
}

struct PodcastChannel: Codable {
    let title: String?
    let description: String?
    let thumbnails: [Thumbnail]?
}

struct Podcast: Codable {
    let title: String?
    let description: String?
    let thumbnails: [Thumbnail]?
}

struct PodcastEpisode: Codable {
    let title: String?
    let description: String?
    let thumbnails: [Thumbnail]?
    let duration: String?
}

struct YTUserProfile: Codable {
    let name: String?
    let thumbnails: [Thumbnail]?
}

