import SwiftUI

struct ProfileSettingsView: View {
    @StateObject private var authManager = AuthManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var showingImagePicker = false
    @State private var inputImage: UIImage?
    @State private var profilePictureUrl: String?
    @State private var isUploading = false
    
    var body: some View {
        ZStack {
            Theme.background.edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 28) {
                    // Profile Picture View
                    ZStack(alignment: .bottomTrailing) {
                        if let inputImage = inputImage {
                            Image(uiImage: inputImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 130, height: 130)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Theme.neonAccent, lineWidth: 2))
                                .shadow(color: Theme.neonAccent.opacity(0.4), radius: 10, x: 0, y: 0)
                        } else {
                            ProfileImageView(urlString: authManager.currentUserProfilePicture)
                                .frame(width: 130, height: 130)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Theme.neonAccent, lineWidth: 2))
                                .shadow(color: Theme.neonAccent.opacity(0.4), radius: 10, x: 0, y: 0)
                        }
                        
                        Button(action: {
                            showingImagePicker = true
                        }) {
                            Image(systemName: "camera.fill")
                                .padding(10)
                                .background(Theme.primary)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .offset(x: -4, y: -4)
                    }
                    .padding(.top, 20)
                    
                    if isUploading {
                        ProgressView("Uploading...")
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.neonAccent))
                            .foregroundColor(.white)
                    }
                    
                    // Theme Selection Section
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("HERO THEME")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.neonAccent)
                                .tracking(2)
                            
                            Spacer()
                            
                            Text("Active: \(themeManager.currentTheme.displayName)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 4)
                        
                        VStack(spacing: 12) {
                            ForEach(AppTheme.allCases) { theme in
                                let isSelected = themeManager.currentTheme == theme
                                
                                Button(action: {
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                    themeManager.setTheme(theme)
                                }) {
                                    HStack(spacing: 14) {
                                        // Theme Icon Badge
                                        ZStack {
                                            Circle()
                                                .fill(theme.primaryColor.opacity(0.2))
                                                .frame(width: 46, height: 46)
                                            
                                            Image(systemName: theme.iconName)
                                                .font(.system(size: 20, weight: .bold))
                                                .foregroundColor(theme.primaryColor)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(theme.displayName)
                                                .font(.headline)
                                                .foregroundColor(.white)
                                            
                                            Text(theme.subtitle)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                                .lineLimit(1)
                                        }
                                        
                                        Spacer()
                                        
                                        // Color Swatches
                                        HStack(spacing: 5) {
                                            Circle()
                                                .fill(theme.primaryColor)
                                                .frame(width: 12, height: 12)
                                            Circle()
                                                .fill(theme.neonAccentColor)
                                                .frame(width: 12, height: 12)
                                            Circle()
                                                .fill(theme.secondaryColor)
                                                .frame(width: 12, height: 12)
                                        }
                                        .padding(.trailing, 6)
                                        
                                        // Selected Radio / Checkmark
                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .font(.title3)
                                            .foregroundColor(isSelected ? theme.primaryColor : .gray.opacity(0.5))
                                    }
                                    .padding(14)
                                    .background(isSelected ? theme.surfaceColor.opacity(0.8) : Color.white.opacity(0.04))
                                    .cornerRadius(14)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(isSelected ? theme.primaryColor : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                                    )
                                    .shadow(color: isSelected ? theme.primaryColor.opacity(0.3) : .clear, radius: 8, x: 0, y: 0)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle("Profile & Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingImagePicker, onDismiss: loadImage) {
            ImagePicker(image: $inputImage)
        }
    }
    
    func loadImage() {
        guard let inputImage = inputImage else { return }
        uploadImage(image: inputImage)
    }
    
    func uploadImage(image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.5) else { return }
        let base64String = imageData.base64EncodedString()
        let dataString = "data:image/jpeg;base64,\(base64String)"
        
        let baseURL = NetworkManager.shared.baseURL
        guard let url = URL(string: "\(baseURL)/auth/profile_picture") else { return }
        guard let token = authManager.token else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["profile_picture_url": dataString]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        isUploading = true
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isUploading = false
                if let data = data {
                    if let responseDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let url = responseDict["profile_picture_url"] as? String {
                            authManager.currentUserProfilePicture = url
                        }
                    }
                }
            }
        }.resume()
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            picker.dismiss(animated: true)
        }
    }
}
