import Foundation
import WidgetKit

// MARK: - Widget Shared Models
struct WidgetSongData: Codable {
    let id: String
    let title: String
    let artist: String
    let album: String?
    let duration_ms: Int
    let cover_art_url: String?
    let isPlaying: Bool
    let progress: Double
    let duration: Double
    let timestamp: Double
    
    static var placeholder: WidgetSongData {
        WidgetSongData(
            id: "demo",
            title: "PKP Music",
            artist: "Tap to Play",
            album: "PKPMusic",
            duration_ms: 210000,
            cover_art_url: nil,
            isPlaying: false,
            progress: 0.35,
            duration: 210.0,
            timestamp: Date().timeIntervalSince1970
        )
    }
}

struct WidgetServerData: Codable {
    let hostname: String
    let local_ip: String
    let uptime_formatted: String
    let cpu_usage_pct: Double
    let temperature_c: Double?
    let memory_used_formatted: String
    let memory_total_formatted: String
    let memory_usage_pct: Double
    let disk_used_formatted: String
    let disk_total_formatted: String
    let disk_usage_pct: Double
    let containers_running: Int
    let containers_total: Int
    let is_online: Bool
    let timestamp: Double
    
    static var placeholder: WidgetServerData {
        WidgetServerData(
            hostname: "pavankumarpotta",
            local_ip: "192.168.1.151",
            uptime_formatted: "83d 3h",
            cpu_usage_pct: 12.5,
            temperature_c: 64.5,
            memory_used_formatted: "2.1 GB",
            memory_total_formatted: "7.9 GB",
            memory_usage_pct: 26.5,
            disk_used_formatted: "50.3 GB",
            disk_total_formatted: "937.3 GB",
            disk_usage_pct: 5.4,
            containers_running: 11,
            containers_total: 11,
            is_online: true,
            timestamp: Date().timeIntervalSince1970
        )
    }
}

// MARK: - App Group Store
class AppGroupStore {
    static let shared = AppGroupStore()
    
    private let appGroupSuite = "group.com.pottapavankumar.PKPMusic"
    private let songKey = "widget_now_playing_song"
    private let recentSongsKey = "widget_recent_songs"
    private let serverKey = "widget_server_telemetry"
    
    private var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupSuite) ?? UserDefaults.standard
    }
    
    // MARK: - Song Sync
    func syncCurrentSong(
        id: String,
        title: String,
        artist: String,
        album: String? = nil,
        duration_ms: Int = 0,
        cover_art_url: String? = nil,
        isPlaying: Bool,
        progress: Double,
        duration: Double
    ) {
        let data = WidgetSongData(
            id: id,
            title: title,
            artist: artist,
            album: album,
            duration_ms: duration_ms,
            cover_art_url: cover_art_url,
            isPlaying: isPlaying,
            progress: progress,
            duration: duration,
            timestamp: Date().timeIntervalSince1970
        )
        
        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: songKey)
        }
        
        // Update recents
        var recents = getRecentSongs()
        recents.removeAll(where: { $0.id == id })
        recents.insert(data, at: 0)
        if recents.count > 5 {
            recents = Array(recents.prefix(5))
        }
        if let encodedRecents = try? JSONEncoder().encode(recents) {
            defaults.set(encodedRecents, forKey: recentSongsKey)
        }
        
        WidgetCenter.shared.reloadTimelines(ofKind: "MusicPlayerWidget")
    }
    
    func clearCurrentSong() {
        defaults.removeObject(forKey: songKey)
        WidgetCenter.shared.reloadTimelines(ofKind: "MusicPlayerWidget")
    }
    
    func getNowPlayingSong() -> WidgetSongData? {
        guard let data = defaults.data(forKey: songKey),
              let song = try? JSONDecoder().decode(WidgetSongData.self, from: data) else {
            return nil
        }
        return song
    }
    
    func getRecentSongs() -> [WidgetSongData] {
        guard let data = defaults.data(forKey: recentSongsKey),
              let list = try? JSONDecoder().decode([WidgetSongData].self, from: data) else {
            return []
        }
        return list
    }
    
    // MARK: - Server Sync
    func syncServerData(_ serverData: WidgetServerData) {
        if let encoded = try? JSONEncoder().encode(serverData) {
            defaults.set(encoded, forKey: serverKey)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "ServerMonitorWidget")
    }
    
    func getServerData() -> WidgetServerData? {
        guard let data = defaults.data(forKey: serverKey),
              let stats = try? JSONDecoder().decode(WidgetServerData.self, from: data) else {
            return nil
        }
        return stats
    }
}
