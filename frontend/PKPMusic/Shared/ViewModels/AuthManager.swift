import Foundation
import Combine

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isAuthenticated: Bool = false
    @Published var token: String? = nil
    @Published var currentUserProfilePicture: String? = nil
    
    private let tokenKey = "pkp_music_auth_token"
    
    init() {
        self.token = UserDefaults.standard.string(forKey: tokenKey)
        self.isAuthenticated = (self.token != nil)
        if self.isAuthenticated {
            fetchMe()
        }
    }
    
    func login(token: String) {
        self.token = token
        UserDefaults.standard.set(token, forKey: tokenKey)
        
        // Ensure UI updates on main thread
        DispatchQueue.main.async {
            self.isAuthenticated = true
        }
        fetchMe()
    }
    
    func fetchMe() {
        let baseURL = NetworkManager.shared.baseURL
        guard let url = URL(string: "\(baseURL)/auth/me") else { return }
        guard let token = token else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data, let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                DispatchQueue.main.async {
                    self.currentUserProfilePicture = dict["profile_picture_url"] as? String
                }
            }
        }.resume()
    }
    
    func logout() {
        self.token = nil
        UserDefaults.standard.removeObject(forKey: tokenKey)
        
        DispatchQueue.main.async {
            self.isAuthenticated = false
        }
    }
}
