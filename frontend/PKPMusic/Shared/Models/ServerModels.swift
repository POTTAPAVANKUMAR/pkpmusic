import Foundation

// MARK: - System Metrics
struct SystemMetrics: Codable {
    let hostname: String
    let os_name: String
    let arch: String
    let local_ip: String
    let uptime_seconds: Double
    let uptime_formatted: String
    let cpu_count: Int
    let load_avg: [Double]
    let cpu_usage_pct: Double
    let temperature_c: Double?
    let memory: MemoryMetrics
    let disk: DiskMetrics
}

struct MemoryMetrics: Codable {
    let total_bytes: Int64
    let used_bytes: Int64
    let free_bytes: Int64
    let total_formatted: String
    let used_formatted: String
    let free_formatted: String
    let usage_pct: Double
}

struct DiskMetrics: Codable {
    let total_bytes: Int64
    let used_bytes: Int64
    let free_bytes: Int64
    let total_formatted: String
    let used_formatted: String
    let free_formatted: String
    let usage_pct: Double
}

// MARK: - Docker Container
struct DockerContainerInfo: Identifiable, Codable {
    let id: String
    let short_id: String
    let name: String
    let image: String
    let state: String
    let status: String
    let is_running: Bool
    let created: Int64
    let ports: [String]
}

// MARK: - Cloudflare Service Health
struct ServiceHealthInfo: Identifiable, Codable {
    var id: String { name }
    let name: String
    let url: String
    let service: String
    let port: Int
    let icon: String
    let is_online: Bool
    let status_code: Int
    let latency_ms: Int
}

// MARK: - Prune Result
struct ServerPruneResult: Codable {
    let success: Bool
    let space_reclaimed_formatted: String?
    let containers_deleted: Int?
    let images_deleted: Int?
    let error: String?
}

// MARK: - File Explorer Models
struct ServerFileItem: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let path: String
    let is_dir: Bool
    let size_bytes: Int64
    let size_formatted: String
    let modified_time: Double
    let modified_formatted: String
    let extension_type: String
    let icon: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, path, is_dir, size_bytes, size_formatted, modified_time, modified_formatted, icon
        case extension_type = "extension"
    }
}

struct ServerDirectoryListing: Codable {
    let current_path: String
    let display_path: String
    let parent_path: String?
    let display_parent: String?
    let items: [ServerFileItem]
    let item_count: Int
}

struct ServerFileDetail: Codable {
    let path: String
    let display_path: String
    let name: String
    let content: String
    let size_bytes: Int64
    let size_formatted: String
    let is_text: Bool
}

