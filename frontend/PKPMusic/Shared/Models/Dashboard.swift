import Foundation

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

struct DashboardSection: Codable, Identifiable {
    var id: String { title }
    let title: String
    let items: [DashboardItem]
}
