import WidgetKit
import SwiftUI

// MARK: - Timeline Entry
struct MusicPlayerEntry: TimelineEntry {
    let date: Date
    let song: WidgetSongData
    let recentSongs: [WidgetSongData]
}

// MARK: - Timeline Provider
struct MusicPlayerProvider: TimelineProvider {
    func placeholder(in context: Context) -> MusicPlayerEntry {
        MusicPlayerEntry(date: Date(), song: .placeholder, recentSongs: [.placeholder])
    }

    func getSnapshot(in context: Context, completion: @escaping (MusicPlayerEntry) -> Void) {
        let song = AppGroupStore.shared.getNowPlayingSong() ?? .placeholder
        let recents = AppGroupStore.shared.getRecentSongs()
        let entry = MusicPlayerEntry(date: Date(), song: song, recentSongs: recents)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MusicPlayerEntry>) -> Void) {
        let song = AppGroupStore.shared.getNowPlayingSong() ?? .placeholder
        let recents = AppGroupStore.shared.getRecentSongs()
        let entry = MusicPlayerEntry(date: Date(), song: song, recentSongs: recents)
        
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget View
struct MusicPlayerWidgetEntryView: View {
    var entry: MusicPlayerProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallPlayerView
        case .systemMedium:
            mediumPlayerView
        case .systemLarge:
            largePlayerView
        case .accessoryRectangular:
            lockScreenRectangularView
        case .accessoryCircular:
            lockScreenCircularView
        case .accessoryInline:
            lockScreenInlineView
        @unknown default:
            mediumPlayerView
        }
    }

    // MARK: - 1. Small Widget
    private var smallPlayerView: some View {
        ZStack {
            widgetBackground
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LinearGradient(colors: [Color.red.opacity(0.8), Color.blue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "music.note")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 3) {
                        Image(systemName: entry.song.isPlaying ? "waveform" : "pause.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(entry.song.isPlaying ? .green : .gray)
                        Text(entry.song.isPlaying ? "Playing" : "Paused")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(entry.song.isPlaying ? .green : .gray)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.song.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(entry.song.artist)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
                
                // Mini progress line
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 3)
                        
                        let ratio = entry.song.duration > 0 ? (entry.song.progress / entry.song.duration) : 0.35
                        RoundedRectangle(cornerRadius: 2)
                            .fill(LinearGradient(colors: [.red, .cyan], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(min(max(ratio, 0.05), 1.0)), height: 3)
                    }
                }
                .frame(height: 3)
            }
            .padding(14)
        }
        .widgetURL(URL(string: "pkpmusic://nowplaying"))
    }

    // MARK: - 2. Medium Widget
    private var mediumPlayerView: some View {
        ZStack {
            widgetBackground
            
            HStack(spacing: 14) {
                // Album Art Card
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearGradient(colors: [Color.red.opacity(0.8), Color.purple.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 86, height: 86)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: .red.opacity(0.3), radius: 6, x: 0, y: 3)
                    
                    Image(systemName: "music.quarternote.3")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                    
                    if entry.song.isPlaying {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 10, height: 10)
                                    .padding(6)
                            }
                        }
                        .frame(width: 86, height: 86)
                    }
                }
                
                // Track Info & Controls
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(entry.song.isPlaying ? "NOW PLAYING" : "RECENTLY PLAYED")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.cyan)
                            .tracking(1)
                        
                        Spacer()
                        
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                    }
                    
                    Text(entry.song.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(entry.song.artist)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Progress bar + Time
                    VStack(spacing: 3) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white.opacity(0.15))
                                    .frame(height: 4)
                                
                                let ratio = entry.song.duration > 0 ? (entry.song.progress / entry.song.duration) : 0.4
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(LinearGradient(colors: [.red, .cyan], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * CGFloat(min(max(ratio, 0.05), 1.0)), height: 4)
                            }
                        }
                        .frame(height: 4)
                        
                        HStack {
                            Text(formatTime(entry.song.progress))
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text(formatTime(entry.song.duration))
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
            }
            .padding(14)
        }
        .widgetURL(URL(string: "pkpmusic://nowplaying"))
    }

    // MARK: - 3. Large Widget
    private var largePlayerView: some View {
        ZStack {
            widgetBackground
            
            VStack(alignment: .leading, spacing: 12) {
                // Now Playing Header
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(colors: [.red, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 54, height: 54)
                        
                        Image(systemName: "music.note")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("PKP MUSIC")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.cyan)
                            .tracking(1)
                        
                        Text(entry.song.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(entry.song.artist)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Image(systemName: entry.song.isPlaying ? "play.circle.fill" : "pause.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(entry.song.isPlaying ? .green : .gray)
                }
                
                Divider()
                    .background(Color.white.opacity(0.12))
                
                // Up Next Section Header
                HStack {
                    Text("RECENT QUEUE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                        .tracking(1)
                    
                    Spacer()
                    
                    Text("Tap to Play")
                        .font(.system(size: 10))
                        .foregroundColor(.cyan)
                }
                
                // Up Next List
                let recentList = entry.recentSongs.prefix(3)
                VStack(spacing: 8) {
                    if recentList.isEmpty {
                        HStack {
                            Spacer()
                            Text("No recent tracks")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .padding(.vertical, 10)
                    } else {
                        ForEach(Array(recentList.enumerated()), id: \.offset) { index, recent in
                            Link(destination: URL(string: "pkpmusic://play?id=\(recent.id)")!) {
                                HStack(spacing: 10) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.gray)
                                        .frame(width: 14)
                                    
                                    Image(systemName: "music.note")
                                        .font(.system(size: 12))
                                        .foregroundColor(.red)
                                    
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(recent.title)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        
                                        Text(recent.artist)
                                            .font(.system(size: 10))
                                            .foregroundColor(.gray)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.cyan)
                                }
                                .padding(8)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding(14)
        }
    }

    // MARK: - 4. Lock Screen Widgets
    private var lockScreenRectangularView: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.song.isPlaying ? "waveform" : "music.note")
                .font(.system(size: 16, weight: .bold))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.song.title)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                
                Text(entry.song.artist)
                    .font(.system(size: 10))
                    .lineLimit(1)
                
                Text(entry.song.isPlaying ? "Playing" : "PKPMusic")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    private var lockScreenCircularView: some View {
        ZStack {
            Circle().strokeBorder(lineWidth: 2)
            Image(systemName: entry.song.isPlaying ? "waveform" : "music.note")
                .font(.system(size: 14))
        }
    }

    private var lockScreenInlineView: some View {
        Text("🎵 \(entry.song.title) • \(entry.song.artist)")
    }

    // MARK: - Helpers
    private var widgetBackground: some View {
        LinearGradient(
            colors: [Color(red: 0.08, green: 0.09, blue: 0.13), Color(red: 0.04, green: 0.04, blue: 0.07)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite && seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Widget Configuration
struct MusicPlayerWidget: Widget {
    let kind: String = "MusicPlayerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MusicPlayerProvider()) { entry in
            MusicPlayerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Now Playing")
        .description("View currently playing song, album art, and playback progress.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline
        ])
    }
}
