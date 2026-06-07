import SwiftUI

struct Theme {
    static let spiderRed = Color(hex: "E23636")
    static let spiderNeonRed = Color(hex: "FF2A2A")
    static let spiderBlack = Color(hex: "0B0C10")
    static let spiderDarkGrey = Color(hex: "1F2833")
    
    struct SpiderBackground: View {
        @State private var pulse = false
        var body: some View {
            ZStack {
                Theme.spiderBlack.edgesIgnoringSafeArea(.all)
                RadialGradient(gradient: Gradient(colors: [Theme.spiderDarkGrey.opacity(pulse ? 0.9 : 0.5), Theme.spiderBlack]),
                               center: .top,
                               startRadius: pulse ? 100 : 20,
                               endRadius: pulse ? 800 : 500)
                    .edgesIgnoringSafeArea(.all)
                    .animation(Animation.easeInOut(duration: 4.0).repeatForever(autoreverses: true), value: pulse)
                    .onAppear {
                        pulse = true
                    }
            }
        }
    }
    
    struct SwingingMilesView: View {
        @State private var swingAngle: Double = -25
        
        var body: some View {
            GeometryReader { geo in
                ZStack(alignment: .top) {
                    // Web string
                    Rectangle()
                        .fill(LinearGradient(gradient: Gradient(colors: [.white.opacity(0.8), .white.opacity(0.0)]), startPoint: .top, endPoint: .bottom))
                        .frame(width: 2, height: 400)
                    
                    // Spider-Man Image
                    Image("swinging_hero")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .offset(y: 350) // Position him at the end of the web
                        .rotationEffect(.degrees(-swingAngle * 0.3)) // Adjust posture slightly while swinging
                        .shadow(color: Theme.spiderNeonRed.opacity(0.8), radius: 20, x: 0, y: 0)
                }
                .frame(width: 250, height: 600, alignment: .top)
                // Anchor the rotation at the very top of the web
                .rotationEffect(.degrees(swingAngle), anchor: .top)
                .position(x: geo.size.width / 2, y: -20) // Hang from the exact middle of the screen!
                .onAppear {
                    withAnimation(Animation.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                        swingAngle = 25
                    }
                }
            }
            .allowsHitTesting(false) // Let touches pass through to the UI below
        }
    }
}

struct GlitchEffect: ViewModifier {
    @State private var isGlitching = false
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .offset(x: isGlitching ? 3 : -3, y: isGlitching ? -2 : 2)
                .opacity(isGlitching ? 0.6 : 1.0)
                .foregroundColor(isGlitching ? Theme.spiderNeonRed : nil)
            content
                .offset(x: isGlitching ? -4 : 0, y: isGlitching ? 2 : 0)
                .opacity(isGlitching ? 0.4 : 1.0)
                .foregroundColor(isGlitching ? .cyan : nil)
            content
        }
        .animation(Animation.default.speed(30), value: isGlitching)
        .onAppear {
            // Random glitching intervals
            Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                if Bool.random() {
                    isGlitching = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        isGlitching = false
                    }
                }
            }
        }
    }
}

extension View {
    func spiderGlitch() -> some View {
        self.modifier(GlitchEffect())
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
