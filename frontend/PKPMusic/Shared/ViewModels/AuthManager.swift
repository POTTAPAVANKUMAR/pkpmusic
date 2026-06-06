import Foundation
import Combine

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isAuthenticated: Bool = false
    @Published var token: String? = nil
    
    private let tokenKey = "pkp_music_auth_token"
    
    init() {
        self.token = UserDefaults.standard.string(forKey: tokenKey)
        self.isAuthenticated = (self.token != nil)
    }
    
    func login(token: String) {
        self.token = token
        UserDefaults.standard.set(token, forKey: tokenKey)
        
        // Ensure UI updates on main thread
        DispatchQueue.main.async {
            self.isAuthenticated = true
        }
    }
    
    func logout() {
        self.token = nil
        UserDefaults.standard.removeObject(forKey: tokenKey)
        
        DispatchQueue.main.async {
            self.isAuthenticated = false
        }
    }
}
