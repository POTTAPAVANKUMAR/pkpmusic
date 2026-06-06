import SwiftUI

struct Theme {
    static let spiderRed = Color(hex: "E23636")
    static let spiderNeonRed = Color(hex: "FF2A2A")
    static let spiderBlack = Color(hex: "0B0C10")
    static let spiderDarkGrey = Color(hex: "1F2833")
    
    struct SpiderBackground: View {
        var body: some View {
            ZStack {
                Theme.spiderBlack.edgesIgnoringSafeArea(.all)
                RadialGradient(gradient: Gradient(colors: [Theme.spiderDarkGrey.opacity(0.8), Theme.spiderBlack]),
                               center: .top,
                               startRadius: 50,
                               endRadius: 600)
                    .edgesIgnoringSafeArea(.all)
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
