import WidgetKit
import SwiftUI

// MARK: - Timeline Entry
struct QuickLauncherEntry: TimelineEntry {
    let date: Date
}

// MARK: - Timeline Provider
struct QuickLauncherProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickLauncherEntry {
        QuickLauncherEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickLauncherEntry) -> Void) {
        completion(QuickLauncherEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickLauncherEntry>) -> Void) {
        let entry = QuickLauncherEntry(date: Date())
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget View
struct QuickLauncherWidgetEntryView: View {
    var entry: QuickLauncherProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallLauncherView
        case .systemMedium:
            mediumLauncherView
        default:
            mediumLauncherView
        }
    }

    // MARK: - 1. Small 2x2 Grid
    private var smallLauncherView: some View {
        ZStack {
            widgetBackground
            
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    LauncherButton(title: "Search", icon: "magnifyingglass", color: .cyan, url: "pkpmusic://search")
                    LauncherButton(title: "Offline", icon: "arrow.down.circle.fill", color: .green, url: "pkpmusic://offline")
                }
                HStack(spacing: 8) {
                    LauncherButton(title: "Server", icon: "server.rack", color: .orange, url: "pkpmusic://server")
                    LauncherButton(title: "Chat", icon: "message.fill", color: .purple, url: "pkpmusic://chat")
                }
            }
            .padding(10)
        }
    }

    // MARK: - 2. Medium 4-Tile Row
    private var mediumLauncherView: some View {
        ZStack {
            widgetBackground
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 11))
                    Text("PKP MUSIC SHORTCUTS")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.gray)
                        .tracking(1)
                    
                    Spacer()
                }
                
                HStack(spacing: 10) {
                    LauncherTile(title: "Explore", subtitle: "Search songs", icon: "safari.fill", color: .cyan, url: "pkpmusic://explore")
                    LauncherTile(title: "Offline", subtitle: "Downloaded", icon: "arrow.down.circle.fill", color: .green, url: "pkpmusic://offline")
                    LauncherTile(title: "Server", subtitle: "Pi Hub", icon: "server.rack", color: .orange, url: "pkpmusic://server")
                    LauncherTile(title: "Chat", subtitle: "Rooms", icon: "message.fill", color: .purple, url: "pkpmusic://chat")
                }
            }
            .padding(14)
        }
    }

    // MARK: - Helpers
    private var widgetBackground: some View {
        LinearGradient(
            colors: [Color(red: 0.08, green: 0.08, blue: 0.12), Color(red: 0.04, green: 0.04, blue: 0.06)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Subviews
struct LauncherButton: View {
    let title: String
    let icon: String
    let color: Color
    let url: String
    
    var body: some View {
        Link(destination: URL(string: url)!) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.opacity(0.06))
            .cornerRadius(10)
        }
    }
}

struct LauncherTile: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let url: String
    
    var body: some View {
        Link(destination: URL(string: url)!) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.2))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(color)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(8)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }
}

// MARK: - Widget Configuration
struct QuickLauncherWidget: Widget {
    let kind: String = "QuickLauncherWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickLauncherProvider()) { entry in
            QuickLauncherWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Quick Shortcuts")
        .description("One-tap fast launch into Search, Offline Music, Server Hub, and Chat.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium
        ])
    }
}
