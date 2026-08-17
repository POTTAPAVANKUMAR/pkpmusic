import SwiftUI

struct ProfileImageView: View {
    let urlString: String?
    
    var body: some View {
        if let urlString = urlString, urlString.starts(with: "data:image") {
            let components = urlString.components(separatedBy: ",")
            if components.count > 1, let data = Data(base64Encoded: components[1], options: .ignoreUnknownCharacters), let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                fallbackImage
            }
        } else if let urlString = urlString, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image.resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                fallbackImage
            }
        } else {
            fallbackImage
        }
    }
    
    var fallbackImage: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .foregroundColor(.gray)
    }
}
