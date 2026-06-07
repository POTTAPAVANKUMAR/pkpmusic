import SwiftUI

struct RegisterView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            Theme.SpiderBackground()
            
            VStack(spacing: 30) {
                HStack {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding()
                
                Text("Create Account")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                VStack(spacing: 20) {
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(Theme.spiderRed)
                            .font(.callout)
                            .multilineTextAlignment(.center)
                    }
                    if let success = successMessage {
                        Text(success)
                            .foregroundColor(.green)
                            .font(.callout)
                            .multilineTextAlignment(.center)
                    }
                    
                    CustomTextField(placeholder: "Username", text: $username, icon: "person")
                        .autocapitalization(.none)
                        
                    CustomTextField(placeholder: "Email", text: $email, icon: "envelope")
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    CustomSecureField(placeholder: "Password", text: $password, icon: "lock")
                }
                .padding(.horizontal, 30)
                
                Button(action: register) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Sign Up")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.spiderNeonRed)
                            .cornerRadius(10)
                    }
                }
                .disabled(isLoading || email.isEmpty || password.isEmpty || username.isEmpty)
                .padding(.horizontal, 30)
                
                Spacer()
            }
        }
    }
    
    func register() {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        let url = URL(string: "\(NetworkManager.shared.baseURL)/auth/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["username": username, "email": email.lowercased(), "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                
                guard let data = data else { return }
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    self.successMessage = "Account created! You can now sign in."
                    // Optional: auto login or dismiss
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.presentationMode.wrappedValue.dismiss()
                    }
                } else {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let detail = json["detail"] as? String {
                        self.errorMessage = detail
                    } else {
                        self.errorMessage = "Failed to register"
                    }
                }
            }
        }.resume()
    }
}
