import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case spiderman = "spiderman"
    case batman = "batman"
    case ironman = "ironman"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .spiderman: return "Spider-Man"
        case .batman: return "Batman"
        case .ironman: return "Iron Man"
        }
    }
    
    var subtitle: String {
        switch self {
        case .spiderman: return "Miles Morales Cyber Red & Cyan"
        case .batman: return "The Dark Knight Pitch Black & Gold"
        case .ironman: return "Stark Tech Crimson & Arc Cyan"
        }
    }
    
    var iconName: String {
        switch self {
        case .spiderman: return "sparkles"
        case .batman: return "shield.lefthalf.filled"
        case .ironman: return "bolt.circle.fill"
        }
    }
    
    var primaryColor: Color {
        switch self {
        case .spiderman: return Color(hex: "E23636")
        case .batman: return Color(hex: "FFE600")
        case .ironman: return Color(hex: "E62429")
        }
    }
    
    var neonAccentColor: Color {
        switch self {
        case .spiderman: return Color(hex: "FF2A2A")
        case .batman: return Color(hex: "F5B800")
        case .ironman: return Color(hex: "00F5FF")
        }
    }
    
    var secondaryColor: Color {
        switch self {
        case .spiderman: return Color(hex: "00F0FF")
        case .batman: return Color(hex: "8A9BA8")
        case .ironman: return Color(hex: "FFD700")
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .spiderman: return Color(hex: "0B0C10")
        case .batman: return Color(hex: "030304")
        case .ironman: return Color(hex: "0C0810")
        }
    }
    
    var surfaceColor: Color {
        switch self {
        case .spiderman: return Color(hex: "1F2833")
        case .batman: return Color(hex: "0E1116")
        case .ironman: return Color(hex: "1B1322")
        }
    }
    
    var glowColor: Color {
        switch self {
        case .spiderman: return Color(hex: "FF2A2A")
        case .batman: return Color(hex: "F5B800")
        case .ironman: return Color(hex: "00F5FF")
        }
    }
    
    var tabBarBgColor: UIColor {
        switch self {
        case .spiderman: return UIColor(Color(hex: "0B0C10"))
        case .batman: return UIColor(Color(hex: "030304"))
        case .ironman: return UIColor(Color(hex: "0C0810"))
        }
    }
    
    var tabBarSelectedColor: UIColor {
        switch self {
        case .spiderman: return UIColor(Color(hex: "FF2A2A"))
        case .batman: return UIColor(Color(hex: "FFE600"))
        case .ironman: return UIColor(Color(hex: "E62429"))
        }
    }
}

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    private let themeKey = "selected_app_theme"
    
    @Published var currentTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: themeKey)
            updateTabBarAppearance()
        }
    }
    
    init() {
        if let saved = UserDefaults.standard.string(forKey: themeKey),
           let theme = AppTheme(rawValue: saved) {
            self.currentTheme = theme
        } else {
            self.currentTheme = .spiderman
        }
        updateTabBarAppearance()
    }
    
    func setTheme(_ theme: AppTheme) {
        withAnimation(.easeInOut(duration: 0.3)) {
            self.currentTheme = theme
        }
    }
    
    func updateTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = currentTheme.tabBarBgColor
        
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = UIColor.white.withAlphaComponent(0.5)
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white.withAlphaComponent(0.5)]
        
        itemAppearance.selected.iconColor = currentTheme.tabBarSelectedColor
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: currentTheme.tabBarSelectedColor]
        
        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance
        
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}
