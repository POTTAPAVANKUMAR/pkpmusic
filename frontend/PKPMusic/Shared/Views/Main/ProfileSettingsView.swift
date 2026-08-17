import SwiftUI

struct ProfileSettingsView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var showingImagePicker = false
    @State private var inputImage: UIImage?
    @State private var profilePictureUrl: String?
    @State private var isUploading = false
    
    // We don't have a full User struct in frontend right now.
    // So we'll fetch the profile_picture_url or we can just upload it.
    
    var body: some View {
        ZStack {
            Theme.spiderBlack.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                // Profile Picture View
                ZStack(alignment: .bottomTrailing) {
                    if let inputImage = inputImage {
                        Image(uiImage: inputImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 150, height: 150)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Theme.spiderNeonRed, lineWidth: 2))
                    } else {
                        ProfileImageView(urlString: authManager.currentUserProfilePicture)
                            .frame(width: 150, height: 150)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Theme.spiderNeonRed, lineWidth: 2))
                    }
                    
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        Image(systemName: "camera.fill")
                            .padding(10)
                            .background(Theme.spiderRed)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                    .offset(x: -5, y: -5)
                }
                .padding(.top, 50)
                
                Text("Update Profile")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.white)
                
                if isUploading {
                    ProgressView("Uploading...")
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.spiderNeonRed))
                        .foregroundColor(.white)
                }
                
                Spacer()
            }
        }
        .navigationTitle("Profile")
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
