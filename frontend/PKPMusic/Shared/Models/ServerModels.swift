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
