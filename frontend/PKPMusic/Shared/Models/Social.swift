import Foundation

struct ChatUser: Identifiable, Codable {
    let id: Int
    let username: String
}

struct Friendship: Identifiable, Codable {
    let id: Int
    let userId: Int
    let friendId: Int
    let status: String
    let createdAt: Double
    let friend: ChatUser
    
    enum CodingKeys: String, CodingKey {
        case id, status, friend
        case userId = "user_id"
        case friendId = "friend_id"
        case createdAt = "created_at"
    }
}

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: Int
    let senderId: Int
    let receiverId: Int
    let content: String
    let messageType: String
    let timestamp: Double
    
    enum CodingKeys: String, CodingKey {
        case id, content, timestamp
        case senderId = "sender_id"
        case receiverId = "receiver_id"
        case messageType = "message_type"
    }
}
