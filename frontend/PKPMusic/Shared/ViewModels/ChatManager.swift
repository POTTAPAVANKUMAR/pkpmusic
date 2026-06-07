import Foundation
import Combine

class ChatManager: ObservableObject {
    @Published var friends: [Friendship] = []
    @Published var pendingRequests: [Friendship] = []
    @Published var searchResults: [ChatUser] = []
    @Published var availableUsers: [ChatUser] = []
    
    
    // friendId -> list of messages
    @Published var messages: [Int: [ChatMessage]] = [:]
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var cancellables = Set<AnyCancellable>()
    
    let baseURL = "http://localhost:8000" // Should use environment variable or AuthManager's base URL
    let wsURL = "ws://localhost:8000/ws/chat"
    
    // Start WebSocket Connection
    func connectWebSocket(token: String) {
        guard let url = URL(string: "\(wsURL)?token=\(token)") else { return }
        
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        receiveMessage()
    }
    
    func disconnectWebSocket() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }
    
    // Listen for incoming WS messages
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .failure(let error):
                print("WebSocket receive error: \(error)")
                // Optionally attempt to reconnect here
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleIncomingText(text)
                case .data(let data):
                    print("Received binary data: \(data)")
                @unknown default:
                    break
                }
                
                // Keep listening
                self?.receiveMessage()
            }
        }
    }
    
    private func handleIncomingText(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        do {
            let decoder = JSONDecoder()
            let msg = try decoder.decode(ChatMessage.self, from: data)
            
            DispatchQueue.main.async {
                // If I am the sender, the other person is the friend (receiverId). If I am the receiver, the other person is the sender.
                // We need to figure out which chat room this belongs to.
                // Actually, the sender might be us (echo), or someone else.
                // We don't have our own userId easily accessible here unless passed.
                // Let's assume AuthManager has userId, but for now we'll just use senderId or receiverId depending on which is not us.
                // Wait, if we send a message, we get an echo where senderId == ourId.
                // We can just append the message to both possible keys and use the one that exists, or better, pass our own user_id when initializing.
                
                // We'll let ChatDetailView handle the logic by fetching the history first.
                // For now, let's just trigger a notification or refresh.
                NotificationCenter.default.post(name: NSNotification.Name("NewChatMessage"), object: msg)
            }
        } catch {
            print("Failed to decode message: \(error)")
        }
    }
    
    func sendMessage(receiverId: Int, content: String, messageType: String = "text") {
        let payload: [String: Any] = [
            "receiver_id": receiverId,
            "content": content,
            "message_type": messageType
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let stringData = String(data: data, encoding: .utf8) else { return }
        
        let message = URLSessionWebSocketTask.Message.string(stringData)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("WebSocket send error: \(error)")
            }
        }
    }
    
    // REST API Calls
    
    func fetchFriends(token: String) {
        guard let url = URL(string: "\(baseURL)/social/friends") else { return }
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data {
                let decoder = JSONDecoder()
                if let decoded = try? decoder.decode([Friendship].self, from: data) {
                    DispatchQueue.main.async {
                        self.friends = decoded
                    }
                }
            }
        }.resume()
    }
    
    func fetchAllUsers(token: String) {
        guard let url = URL(string: "\(baseURL)/social/users") else { return }
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data {
                let decoder = JSONDecoder()
                if let decoded = try? decoder.decode([ChatUser].self, from: data) {
                    DispatchQueue.main.async {
                        self.availableUsers = decoded
                    }
                }
            }
        }.resume()
    }
    
    func fetchPendingRequests(token: String) {
        guard let url = URL(string: "\(baseURL)/social/requests") else { return }
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data {
                let decoder = JSONDecoder()
                if let decoded = try? decoder.decode([Friendship].self, from: data) {
                    DispatchQueue.main.async {
                        self.pendingRequests = decoded
                    }
                }
            }
        }.resume()
    }
    
    func searchUsers(query: String, token: String) {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/social/search?q=\(encoded)") else { return }
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data {
                let decoder = JSONDecoder()
                if let decoded = try? decoder.decode([ChatUser].self, from: data) {
                    DispatchQueue.main.async {
                        self.searchResults = decoded
                    }
                }
            }
        }.resume()
    }
    
    func sendRequest(friendId: Int, token: String) {
        guard let url = URL(string: "\(baseURL)/social/request") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["friend_id": friendId])
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            // Refresh pending requests or show toast
        }.resume()
    }
    
    func acceptRequest(friendId: Int, token: String) {
        guard let url = URL(string: "\(baseURL)/social/accept") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["friend_id": friendId])
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.fetchFriends(token: token)
                self.fetchPendingRequests(token: token)
            }
        }.resume()
    }
    
    func fetchChatHistory(friendId: Int, token: String) {
        guard let url = URL(string: "\(baseURL)/social/chat/\(friendId)") else { return }
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data {
                let decoder = JSONDecoder()
                if let decoded = try? decoder.decode([ChatMessage].self, from: data) {
                    DispatchQueue.main.async {
                        // Reverse so oldest is first
                        self.messages[friendId] = decoded.reversed()
                    }
                }
            }
        }.resume()
    }
}
