import WidgetKit
import SwiftUI

// MARK: - Timeline Entry
struct ServerMonitorEntry: TimelineEntry {
    let date: Date
    let server: WidgetServerData
}

// MARK: - Timeline Provider
struct ServerMonitorProvider: TimelineProvider {
    func placeholder(in context: Context) -> ServerMonitorEntry {
        ServerMonitorEntry(date: Date(), server: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (ServerMonitorEntry) -> Void) {
        let server = AppGroupStore.shared.getServerData() ?? .placeholder
        let entry = ServerMonitorEntry(date: Date(), server: server)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ServerMonitorEntry>) -> Void) {
        let server = AppGroupStore.shared.getServerData() ?? .placeholder
        let entry = ServerMonitorEntry(date: Date(), server: server)
        
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 10, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget View
struct ServerMonitorWidgetEntryView: View {
    var entry: ServerMonitorProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallServerView
        case .systemMedium:
            mediumServerView
        case .accessoryRectangular:
            lockScreenRectangularView
        case .accessoryInline:
            lockScreenInlineView
        case .accessoryCircular:
            lockScreenCircularView
        default:
            mediumServerView
        }
    }

    // MARK: - 1. Small Widget
    private var smallServerView: some View {
        ZStack {
            widgetBackground
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.cyan)
                        Text("Raspberry Pi")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Circle()
                        .fill(entry.server.is_online ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                }
                
                Spacer()
                
                // Big Temperature
                VStack(alignment: .leading, spacing: 1) {
                    Text("TEMP")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.gray)
                        .tracking(1)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        if let temp = entry.server.temperature_c {
                            Text(String(format: "%.1f", temp))
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                                .foregroundColor(tempColor(temp))
                            Text("°C")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(tempColor(temp).opacity(0.8))
                        } else {
                            Text("--.-")
                                .font(.system(size: 26, weight: .heavy))
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                // Mini Stats
                HStack(spacing: 8) {
                    MiniStatBadge(label: "CPU", value: "\(Int(entry.server.cpu_usage_pct))%", color: .blue)
                    MiniStatBadge(label: "RAM", value: "\(Int(entry.server.memory_usage_pct))%", color: .purple)
                }
            }
            .padding(14)
        }
        .widgetURL(URL(string: "pkpmusic://server"))
    }

    // MARK: - 2. Medium Widget
    private var mediumServerView: some View {
        ZStack {
            widgetBackground
            
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack {
                    Image(systemName: "server.rack")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.cyan)
                    
                    Text(entry.server.hostname)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("(\(entry.server.local_ip))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(entry.server.is_online ? Color.green : Color.red)
                            .frame(width: 7, height: 7)
                        Text(entry.server.is_online ? "ONLINE" : "OFFLINE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(entry.server.is_online ? .green : .red)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(6)
                }
                
                // Telemetry 4-Pill Grid
                HStack(spacing: 8) {
                    // Temp
                    ServerTelemetryTile(
                        icon: "thermometer.medium",
                        title: "TEMP",
                        value: entry.server.temperature_c != nil ? String(format: "%.1f°C", entry.server.temperature_c!) : "N/A",
                        subtitle: "SoC Thermal",
                        color: entry.server.temperature_c != nil ? tempColor(entry.server.temperature_c!) : .orange
                    )
                    
                    // CPU
                    ServerTelemetryTile(
                        icon: "cpu",
                        title: "CPU LOAD",
                        value: String(format: "%.1f%%", entry.server.cpu_usage_pct),
                        subtitle: "\(entry.server.uptime_formatted) up",
                        color: .blue
                    )
                    
                    // RAM
                    ServerTelemetryTile(
                        icon: "memorychip",
                        title: "RAM",
                        value: String(format: "%.0f%%", entry.server.memory_usage_pct),
                        subtitle: "\(entry.server.memory_used_formatted)",
                        color: .purple
                    )
                    
                    // Docker
                    ServerTelemetryTile(
                        icon: "shippingbox.fill",
                        title: "DOCKER",
                        value: "\(entry.server.containers_running) / \(entry.server.containers_total)",
                        subtitle: "Active",
                        color: .green
                    )
                }
            }
            .padding(14)
        }
        .widgetURL(URL(string: "pkpmusic://server"))
    }

    // MARK: - 3. Lock Screen Widgets
    private var lockScreenRectangularView: some View {
        HStack(spacing: 8) {
            Image(systemName: "server.rack")
                .font(.system(size: 16))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.server.hostname)
                    .font(.system(size: 12, weight: .bold))
                
                HStack(spacing: 4) {
                    if let temp = entry.server.temperature_c {
                        Text(String(format: "%.1f°C", temp))
                    }
                    Text("•")
                    Text("\(Int(entry.server.memory_usage_pct))% RAM")
                    Text("•")
                    Text("\(entry.server.containers_running) Apps")
                }
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    private var lockScreenCircularView: some View {
        ZStack {
            Circle().strokeBorder(lineWidth: 2)
            VStack(spacing: 0) {
                Image(systemName: "thermometer.medium")
                    .font(.system(size: 11))
                if let temp = entry.server.temperature_c {
                    Text(String(format: "%.0f°", temp))
                        .font(.system(size: 10, weight: .bold))
                }
            }
        }
    }

    private var lockScreenInlineView: some View {
        let tempStr = entry.server.temperature_c != nil ? String(format: "%.1f°C", entry.server.temperature_c!) : "Online"
        return Text("🖥️ Pi: \(tempStr) • \(Int(entry.server.memory_usage_pct))% RAM")
    }

    // MARK: - Helpers
    private var widgetBackground: some View {
        LinearGradient(
            colors: [Color(red: 0.06, green: 0.08, blue: 0.12), Color(red: 0.03, green: 0.04, blue: 0.06)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func tempColor(_ temp: Double) -> Color {
        if temp < 55 { return .green }
        if temp < 70 { return .orange }
        return .red
    }
}

// MARK: - Subviews
struct MiniStatBadge: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(5)
        .background(Color.white.opacity(0.05))
        .cornerRadius(6)
    }
}

struct ServerTelemetryTile: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(title)
                .font(.system(size: 7, weight: .black))
                .foregroundColor(.gray)
                .tracking(0.5)
            
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Text(subtitle)
                .font(.system(size: 8))
                .foregroundColor(.gray)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(7)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Widget Configuration
struct ServerMonitorWidget: Widget {
    let kind: String = "ServerMonitorWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ServerMonitorProvider()) { entry in
            ServerMonitorWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Server Monitor")
        .description("Live Raspberry Pi CPU temperature, memory, disk, and Docker container status.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline
        ])
    }
}
