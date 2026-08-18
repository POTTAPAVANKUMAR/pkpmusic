import SwiftUI

struct Theme {
    // Dynamic accessors delegating to ThemeManager
    static var spiderRed: Color { ThemeManager.shared.currentTheme.primaryColor }
    static var spiderNeonRed: Color { ThemeManager.shared.currentTheme.neonAccentColor }
    static var spiderBlack: Color { ThemeManager.shared.currentTheme.backgroundColor }
    static var spiderDarkGrey: Color { ThemeManager.shared.currentTheme.surfaceColor }
    
    // Semantic aliases
    static var primary: Color { ThemeManager.shared.currentTheme.primaryColor }
    static var neonAccent: Color { ThemeManager.shared.currentTheme.neonAccentColor }
    static var secondaryAccent: Color { ThemeManager.shared.currentTheme.secondaryColor }
    static var background: Color { ThemeManager.shared.currentTheme.backgroundColor }
    static var surface: Color { ThemeManager.shared.currentTheme.surfaceColor }
    static var glow: Color { ThemeManager.shared.currentTheme.glowColor }
    
    // Background Aliased for compatibility
    typealias SpiderBackground = DynamicBackground
    typealias SwingingMilesView = DynamicHeroView
    
    struct DynamicBackground: View {
        @ObservedObject private var themeManager = ThemeManager.shared
        @State private var pulse = false
        
        var body: some View {
            ZStack {
                themeManager.currentTheme.backgroundColor.edgesIgnoringSafeArea(.all)
                
                switch themeManager.currentTheme {
                case .spiderman:
                    RadialGradient(
                        gradient: Gradient(colors: [themeManager.currentTheme.surfaceColor.opacity(pulse ? 0.9 : 0.5), themeManager.currentTheme.backgroundColor]),
                        center: .top,
                        startRadius: pulse ? 100 : 20,
                        endRadius: pulse ? 800 : 500
                    )
                    .edgesIgnoringSafeArea(.all)
                    .animation(Animation.easeInOut(duration: 4.0).repeatForever(autoreverses: true), value: pulse)
                    
                case .batman:
                    // Gotham Noir Vignette
                    ZStack {
                        RadialGradient(
                            gradient: Gradient(colors: [Color.white.opacity(pulse ? 0.05 : 0.01), themeManager.currentTheme.backgroundColor]),
                            center: .top,
                            startRadius: 10,
                            endRadius: pulse ? 700 : 450
                        )
                        .edgesIgnoringSafeArea(.all)
                        .animation(Animation.easeInOut(duration: 5.0).repeatForever(autoreverses: true), value: pulse)
                    }
                    
                case .ironman:
                    // Stark Tech Arc Reactor Core Glow
                    ZStack {
                        RadialGradient(
                            gradient: Gradient(colors: [Color(hex: "00F5FF").opacity(pulse ? 0.12 : 0.05), Color(hex: "E62429").opacity(0.08), themeManager.currentTheme.backgroundColor]),
                            center: .top,
                            startRadius: pulse ? 80 : 30,
                            endRadius: pulse ? 750 : 500
                        )
                        .edgesIgnoringSafeArea(.all)
                        .animation(Animation.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: pulse)
                    }
                }
            }
            .onAppear {
                pulse = true
            }
        }
    }
    
    struct DynamicHeroView: View {
        @ObservedObject private var themeManager = ThemeManager.shared
        
        var body: some View {
            Group {
                switch themeManager.currentTheme {
                case .spiderman:
                    MilesSwingingView()
                case .batman:
                    BatmanGlidingView()
                case .ironman:
                    IronManHoverView()
                }
            }
            .allowsHitTesting(false)
        }
    }
    
    struct MilesSwingingView: View {
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
                        .offset(y: 350)
                        .rotationEffect(.degrees(-swingAngle * 0.3))
                        .shadow(color: Color(hex: "FF2A2A").opacity(0.8), radius: 20, x: 0, y: 0)
                }
                .frame(width: 250, height: 600, alignment: .top)
                .rotationEffect(.degrees(swingAngle), anchor: .top)
                .position(x: geo.size.width / 2, y: -20)
                .onAppear {
                    withAnimation(Animation.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                        swingAngle = 25
                    }
                }
            }
        }
    }
    
    struct BatSymbol: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            let w = rect.width
            let h = rect.height
            
            path.move(to: CGPoint(x: w * 0.48, y: h * 0.2))
            path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.3))
            path.addLine(to: CGPoint(x: w * 0.52, y: h * 0.2))
            
            path.addQuadCurve(to: CGPoint(x: w * 0.95, y: h * 0.3), control: CGPoint(x: w * 0.75, y: h * 0.15))
            path.addQuadCurve(to: CGPoint(x: w * 0.7, y: h * 0.9), control: CGPoint(x: w * 0.85, y: h * 0.7))
            path.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.95), control: CGPoint(x: w * 0.6, y: h * 0.8))
            
            path.addQuadCurve(to: CGPoint(x: w * 0.3, y: h * 0.9), control: CGPoint(x: w * 0.4, y: h * 0.8))
            path.addQuadCurve(to: CGPoint(x: w * 0.05, y: h * 0.3), control: CGPoint(x: w * 0.15, y: h * 0.7))
            path.addQuadCurve(to: CGPoint(x: w * 0.48, y: h * 0.2), control: CGPoint(x: w * 0.25, y: h * 0.15))
            
            return path
        }
    }
    
    struct BatmanGlidingView: View {
        @State private var pulse = false
        
        var body: some View {
            GeometryReader { geo in
                ZStack {
                    // Bat-Signal spotlight glow at top center
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [Color(hex: "D4AF37").opacity(0.12), Color.clear]),
                                center: .center,
                                startRadius: 10,
                                endRadius: 150
                            )
                        )
                        .frame(width: 200, height: 200)
                        .position(x: geo.size.width / 2, y: 70)
                        .opacity(pulse ? 1.0 : 0.4)
                    
                    // Glowing Bat Symbol
                    BatSymbol()
                        .fill(Color.black)
                        .frame(width: 120, height: 60)
                        .overlay(
                            BatSymbol()
                                .stroke(Color(hex: "FFC107").opacity(0.8), lineWidth: 2)
                                .shadow(color: Color(hex: "D4AF37"), radius: pulse ? 12 : 4, x: 0, y: 0)
                        )
                        .position(x: geo.size.width / 2, y: 70)
                        .scaleEffect(pulse ? 1.02 : 0.98)
                }
                .onAppear {
                    withAnimation(Animation.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                }
            }
        }
    }
    
    struct IronManHoverView: View {
        @State private var hoverY: CGFloat = 35
        @State private var arcPulse = false
        
        var body: some View {
            GeometryReader { geo in
                ZStack {
                    // Floating Stark Tech Arc Reactor Orb
                    VStack(spacing: 2) {
                        ZStack {
                            Circle()
                                .stroke(Color(hex: "FFD700"), lineWidth: 2)
                                .frame(width: 28, height: 28)
                            
                            Circle()
                                .fill(Color(hex: "00F5FF"))
                                .frame(width: 14, height: 14)
                                .shadow(color: Color(hex: "00F5FF").opacity(0.9), radius: arcPulse ? 15 : 6, x: 0, y: 0)
                        }
                        
                        // Repulsor jet flame
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color(hex: "00F5FF"), Color.clear]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 3, height: arcPulse ? 18 : 10)
                    }
                    .position(x: geo.size.width / 2, y: hoverY)
                    .onAppear {
                        withAnimation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                            hoverY = 52
                            arcPulse = true
                        }
                    }
                }
            }
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
