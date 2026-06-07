import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String? = nil
    @State private var isLoading = false
    
    @State private var showRegister = false
    @State private var showForgotPassword = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.SpiderBackground()
                
                VStack(spacing: 30) {
                    // Logo/Header
                    VStack(spacing: 10) {
                        Image(systemName: "music.note.house.fill")
                            .font(.system(size: 80))
                            .foregroundColor(Theme.spiderNeonRed)
                            .shadow(color: Theme.spiderNeonRed.opacity(0.5), radius: 10, x: 0, y: 0)
                            .spiderGlitch()
                        
                        Text("PKP Music")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .spiderGlitch()
                    }
                    .padding(.top, 50)
                    
                    Spacer()
                    
                    // Fields
                    VStack(spacing: 20) {
                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(Theme.spiderRed)
                                .font(.callout)
                                .multilineTextAlignment(.center)
                        }
                        
                        CustomTextField(placeholder: "Email", text: $email, icon: "envelope")
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        
                        CustomSecureField(placeholder: "Password", text: $password, icon: "lock")
                        
                        HStack {
                            Spacer()
                            Button(action: { showForgotPassword = true }) {
                                Text("Forgot Password?")
                                    .foregroundColor(.gray)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    // Buttons
                    VStack(spacing: 15) {
                        Button(action: login) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Sign In")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Theme.spiderNeonRed)
                                    .cornerRadius(10)
                                    .shadow(color: Theme.spiderNeonRed.opacity(0.4), radius: 5, x: 0, y: 0)
                            }
                        }
                        .disabled(isLoading || email.isEmpty || password.isEmpty)
                        .padding(.horizontal, 30)
                        
                        Button(action: { showRegister = true }) {
                            Text("Create Account")
                                .font(.headline)
                                .foregroundColor(Theme.spiderNeonRed)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Theme.spiderNeonRed, lineWidth: 2)
                                )
                        }
                        .padding(.horizontal, 30)
                    }
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showRegister) {
                RegisterView()
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView()
            }
        }
    }
    
    func login() {
        isLoading = true
        errorMessage = nil
        
        let url = URL(string: "\(NetworkManager.shared.baseURL)/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["email": email.lowercased(), "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                
                guard let data = data else {
                    self.errorMessage = "No response from server"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let token = json["access_token"] as? String {
                        AuthManager.shared.login(token: token)
                    }
                } else {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let detail = json["detail"] as? String {
                        self.errorMessage = detail
                    } else {
                        self.errorMessage = "Invalid credentials"
                    }
                }
            }
        }.resume()
    }
}

struct CustomTextField: View {
    var placeholder: String
    @Binding var text: String
    var icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 20)
            TextField("", text: $text)
                .placeholder(when: text.isEmpty) {
                    Text(placeholder).foregroundColor(.gray)
                }
                .foregroundColor(.white)
        }
        .padding()
        .background(Theme.spiderDarkGrey)
        .cornerRadius(10)
    }
}

struct CustomSecureField: View {
    var placeholder: String
    @Binding var text: String
    var icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 20)
            SecureField("", text: $text)
                .placeholder(when: text.isEmpty) {
                    Text(placeholder).foregroundColor(.gray)
                }
                .foregroundColor(.white)
        }
        .padding()
        .background(Theme.spiderDarkGrey)
        .cornerRadius(10)
    }
}

// Helper for placeholder in TextField
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
            
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
