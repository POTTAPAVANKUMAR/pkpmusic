import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @State private var email = ""
    @State private var otp = ""
    @State private var newPassword = ""
    
    @State private var step = 1
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
                
                Text(step == 1 ? "Reset Password" : "Enter OTP")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                VStack(spacing: 20) {
                    if let error = errorMessage {
                        Text(error).foregroundColor(Theme.spiderRed).font(.callout).multilineTextAlignment(.center)
                    }
                    if let success = successMessage {
                        Text(success).foregroundColor(.green).font(.callout).multilineTextAlignment(.center)
                    }
                    
                    if step == 1 {
                        CustomTextField(placeholder: "Enter your email", text: $email, icon: "envelope")
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    } else {
                        CustomTextField(placeholder: "6-Digit OTP", text: $otp, icon: "key")
                            .keyboardType(.numberPad)
                        
                        CustomSecureField(placeholder: "New Password", text: $newPassword, icon: "lock")
                    }
                }
                .padding(.horizontal, 30)
                
                Button(action: step == 1 ? sendOTP : verifyOTP) {
                    if isLoading {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(step == 1 ? "Send OTP" : "Reset Password")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.spiderNeonRed)
                            .cornerRadius(10)
                    }
                }
                .disabled(isLoading || (step == 1 && email.isEmpty) || (step == 2 && (otp.isEmpty || newPassword.isEmpty)))
                .padding(.horizontal, 30)
                
                Spacer()
            }
        }
    }
    
    func sendOTP() {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        let url = URL(string: "\(NetworkManager.shared.baseURL)/auth/forgot-password")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["email": email.lowercased()]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    self.successMessage = "If an account exists, an OTP was sent to your email (or check the server logs!)"
                    self.step = 2
                } else {
                    self.errorMessage = "Failed to request OTP"
                }
            }
        }.resume()
    }
    
    func verifyOTP() {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        let url = URL(string: "\(NetworkManager.shared.baseURL)/auth/verify-otp")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["email": email.lowercased(), "otp": otp, "new_password": newPassword]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    self.successMessage = "Password reset successfully! You can now log in."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.presentationMode.wrappedValue.dismiss()
                    }
                } else {
                    if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let detail = json["detail"] as? String {
                        self.errorMessage = detail
                    } else {
                        self.errorMessage = "Failed to reset password. Invalid OTP?"
                    }
                }
            }
        }.resume()
    }
}
