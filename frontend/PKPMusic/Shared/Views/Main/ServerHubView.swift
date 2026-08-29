import SwiftUI

struct ServerHubView: View {
    @StateObject private var serverManager = ServerManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    
    @State private var selectedTab: ContainerFilter = .all
    @State private var showingLogsSheet: Bool = false
    @State private var showingPruneConfirmation: Bool = false
    @State private var showingSpecsSheet: Bool = false
    @State private var selectedWebUrl: URL? = nil
    @State private var searchText: String = ""
    
    enum ContainerFilter: String, CaseIterable {
        case all = "All"
        case running = "Running"
        case stopped = "Stopped"
    }
    
    var filteredContainers: [DockerContainerInfo] {
        serverManager.containers.filter { container in
            switch selectedTab {
            case .all: return true
            case .running: return container.is_running
            case .stopped: return !container.is_running
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                themeManager.currentTheme.backgroundColor.edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // ── 1. Hero Server Overview ───────────────────────────
                        serverOverviewHeader
                        
                        // ── 2. Hardware Telemetry Cards ───────────────────────
                        if let stats = serverManager.systemStats {
                            telemetryGrid(stats: stats)
                        } else if serverManager.isLoading {
                            ProgressView("Connecting to Raspberry Pi...")
                                .foregroundColor(.gray)
                                .padding(.vertical, 20)
                        }
                        
                        // ── 3. Cloudflare Services Health ──────────────────────
                        if !serverManager.services.isEmpty {
                            servicesHealthSection
                        }
                        
                        // ── 4. Quick Server Tools ─────────────────────────────
                        quickToolsSection
                        
                        // ── 5. Docker Containers Hub ───────────────────────────
                        containersSection
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
                .refreshable {
                    serverManager.fetchOverviewData()
                }
            }
            .navigationTitle("Server Hub")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        serverManager.fetchOverviewData()
                    }) {
                        if serverManager.isRefreshing || serverManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: themeManager.currentTheme.primaryColor))
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(themeManager.currentTheme.primaryColor)
                        }
                    }
                }
            }
            .onAppear {
                serverManager.startMonitoring()
            }
            .onDisappear {
                serverManager.stopMonitoring()
            }
            .sheet(isPresented: $showingLogsSheet) {
                ContainerLogsSheet(
                    containerName: serverManager.selectedContainerName ?? "Container",
                    logs: serverManager.selectedContainerLogs ?? "",
                    isLoading: serverManager.isLoadingLogs
                )
            }
            .sheet(isPresented: $showingSpecsSheet) {
                if let stats = serverManager.systemStats {
                    SystemSpecsSheet(stats: stats)
                }
            }
            .sheet(item: $selectedWebUrl) { url in
                SafariView(url: url)
            }
            .alert(isPresented: $serverManager.showAlert) {
                Alert(
                    title: Text("Server Hub"),
                    message: Text(serverManager.alertMessage ?? ""),
                    dismissButton: .default(Text("OK"))
                )
            }
            .actionSheet(isPresented: $showingPruneConfirmation) {
                ActionSheet(
                    title: Text("Clean Docker Cache?"),
                    message: Text("This will remove all stopped containers and unused image layers to free up storage space."),
                    buttons: [
                        .destructive(Text("Prune Unused Space")) {
                            serverManager.pruneDocker()
                        },
                        .cancel()
                    ]
                )
            }
        }
    }
    
    // MARK: - 1. Server Overview Header
    private var serverOverviewHeader: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "server.rack")
                            .font(.title2)
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                        
                        Text(serverManager.systemStats?.hostname.capitalized ?? "Raspberry Pi")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    Text("\(serverManager.systemStats?.arch ?? "aarch64") · \(serverManager.systemStats?.local_ip ?? "192.168.1.151")")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Status Pill
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .shadow(color: .green.opacity(0.8), radius: 4)
                    
                    Text("ONLINE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.15))
                .cornerRadius(12)
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                    Text("Uptime: \(serverManager.systemStats?.uptime_formatted ?? "--")")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                Button(action: { showingSpecsSheet = true }) {
                    HStack(spacing: 4) {
                        Text("System Details")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(themeManager.currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - 2. Telemetry Grid
    private func telemetryGrid(stats: SystemMetrics) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            
            // Thermal Card
            let temp = stats.temperature_c ?? 0.0
            let tempColor: Color = temp < 60 ? .green : (temp < 75 ? .orange : .red)
            let tempStatus: String = temp < 60 ? "Cool" : (temp < 75 ? "Optimal" : "Warm")
            
            TelemetryCard(
                title: "CPU Temperature",
                value: String(format: "%.1f°C", temp),
                subtitle: tempStatus,
                icon: "thermometer.medium",
                tint: tempColor,
                progress: min(1.0, temp / 85.0)
            )
            
            // CPU Usage Card
            TelemetryCard(
                title: "CPU Load",
                value: "\(String(format: "%.1f", stats.cpu_usage_pct))%",
                subtitle: "\(stats.cpu_count) Cores · \(stats.load_avg.first ?? 0.0) 1m",
                icon: "cpu.fill",
                tint: themeManager.currentTheme.primaryColor,
                progress: stats.cpu_usage_pct / 100.0
            )
            
            // RAM Usage Card
            TelemetryCard(
                title: "Memory (RAM)",
                value: "\(stats.memory.used_formatted)",
                subtitle: "of \(stats.memory.total_formatted) (\(Int(stats.memory.usage_pct))%)",
                icon: "memorychip",
                tint: .purple,
                progress: stats.memory.usage_pct / 100.0
            )
            
            // Disk Storage Card
            TelemetryCard(
                title: "Disk Storage",
                value: "\(stats.disk.used_formatted)",
                subtitle: "\(stats.disk.free_formatted) free",
                icon: "internaldrive.fill",
                tint: .blue,
                progress: stats.disk.usage_pct / 100.0
            )
        }
    }
    
    // MARK: - 3. Services Health
    private var servicesHealthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Cloudflare Services")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(serverManager.services.filter { $0.is_online }.count)/\(serverManager.services.count) Active")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(serverManager.services) { svc in
                        Button(action: {
                            if let url = URL(string: svc.url) {
                                selectedWebUrl = url
                            }
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: svc.icon)
                                        .font(.system(size: 16))
                                        .foregroundColor(svc.is_online ? themeManager.currentTheme.primaryColor : .gray)
                                    
                                    Spacer()
                                    
                                    Circle()
                                        .fill(svc.is_online ? Color.green : Color.red)
                                        .frame(width: 7, height: 7)
                                }
                                
                                Text(svc.name)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                HStack {
                                    Text(":\(svc.port)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
                                    
                                    Spacer()
                                    
                                    if svc.latency_ms > 0 {
                                        Text("\(svc.latency_ms)ms")
                                            .font(.system(size: 10))
                                            .foregroundColor(.gray.opacity(0.8))
                                    }
                                }
                            }
                            .padding(12)
                            .frame(width: 140, height: 95)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 4. Quick Server Tools
    private var quickToolsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions & Files")
                .font(.headline)
                .foregroundColor(.white)
            
            // File Explorer Card Link
            NavigationLink(destination: ServerFileExplorerView()) {
                HStack(spacing: 12) {
                    Image(systemName: "folder.badge.gearshape")
                        .font(.system(size: 22))
                        .foregroundColor(.yellow)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Server File Explorer")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Browse, view & edit server files, configs & scripts")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .padding(14)
                .background(Color.yellow.opacity(0.12))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.yellow.opacity(0.35), lineWidth: 1)
                )
            }
            
            HStack(spacing: 12) {
                // Prune Button
                Button(action: {
                    showingPruneConfirmation = true
                }) {
                    HStack {
                        if serverManager.isPruning {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 14))
                        }
                        Text(serverManager.isPruning ? "Cleaning..." : "Clean Docker Space")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange.opacity(0.18))
                    .foregroundColor(.orange)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.orange.opacity(0.4), lineWidth: 1)
                    )
                }
                .disabled(serverManager.isPruning)
                
                // Restart API Container
                Button(action: {
                    if let apiContainer = serverManager.containers.first(where: { $0.name.contains("api") }) {
                        serverManager.performContainerAction(container: apiContainer, action: "restart")
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.system(size: 14))
                        Text("Restart API")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(themeManager.currentTheme.primaryColor.opacity(0.18))
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(themeManager.currentTheme.primaryColor.opacity(0.4), lineWidth: 1)
                    )
                }
            }
        }
    }
    
    // MARK: - 5. Containers Section
    private var containersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Docker Containers")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Picker("Filter", selection: $selectedTab) {
                    ForEach(ContainerFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
            }
            
            if filteredContainers.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "shippingbox")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("No containers found.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                ForEach(filteredContainers) { container in
                    ContainerCard(
                        container: container,
                        isActing: serverManager.actingContainerId == container.id,
                        onAction: { action in
                            serverManager.performContainerAction(container: container, action: action)
                        },
                        onViewLogs: {
                            serverManager.fetchContainerLogs(container: container)
                            showingLogsSheet = true
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Telemetry Card Subview
struct TelemetryCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let tint: Color
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(tint)
                
                Spacer()
                
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 5)
                    
                    Capsule()
                        .fill(tint)
                        .frame(width: max(0, min(geo.size.width * CGFloat(progress), geo.size.width)), height: 5)
                }
            }
            .frame(height: 5)
            
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(.gray.opacity(0.8))
                .lineLimit(1)
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Container Card Subview
struct ContainerCard: View {
    let container: DockerContainerInfo
    let isActing: Bool
    let onAction: (String) -> Void
    let onViewLogs: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(container.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(container.image)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Status Badge
                HStack(spacing: 5) {
                    Circle()
                        .fill(container.is_running ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                    
                    Text(container.state.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(container.is_running ? .green : .red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((container.is_running ? Color.green : Color.red).opacity(0.15))
                .cornerRadius(8)
            }
            
            HStack {
                Text(container.status)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                if let port = container.ports.first {
                    Text(port)
                        .font(.system(size: 10, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(.cyan)
                        .cornerRadius(4)
                }
            }
            
            Divider().background(Color.white.opacity(0.08))
            
            // Actions Row
            HStack(spacing: 8) {
                Button(action: onViewLogs) {
                    HStack(spacing: 4) {
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 11))
                        Text("Logs")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Spacer()
                
                if isActing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding(.horizontal, 12)
                } else {
                    Button(action: { onAction("restart") }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                            .padding(8)
                            .background(Color.white.opacity(0.08))
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                    
                    if container.is_running {
                        Button(action: { onAction("stop") }) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 11))
                                .padding(8)
                                .background(Color.red.opacity(0.2))
                                .foregroundColor(.red)
                                .clipShape(Circle())
                        }
                    } else {
                        Button(action: { onAction("start") }) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 11))
                                .padding(8)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .clipShape(Circle())
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Container Logs Modal Sheet
struct ContainerLogsSheet: View {
    let containerName: String
    let logs: String
    let isLoading: Bool
    
    @Environment(\.presentationMode) var presentationMode
    @State private var filterText: String = ""
    @State private var copied: Bool = false
    
    var filteredLogs: String {
        if filterText.isEmpty { return logs }
        let lines = logs.components(separatedBy: "\n")
        return lines.filter { $0.localizedCaseInsensitiveContains(filterText) }.joined(separator: "\n")
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 12) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Filter logs...", text: $filterText)
                            .foregroundColor(.white)
                        if !filterText.isEmpty {
                            Button(action: { filterText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    if isLoading {
                        Spacer()
                        ProgressView("Streaming logs...")
                            .foregroundColor(.white)
                        Spacer()
                    } else {
                        ScrollView {
                            Text(filteredLogs.isEmpty ? "No matching log entries." : filteredLogs)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.green)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                        }
                        .background(Color(white: 0.05))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 8)
            }
            .navigationTitle("\(containerName) Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        UIPasteboard.general.string = logs
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            copied = false
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            Text(copied ? "Copied" : "Copy")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    }
                }
            }
        }
    }
}

// MARK: - System Specs Sheet
struct SystemSpecsSheet: View {
    let stats: SystemMetrics
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(white: 0.08).edgesIgnoringSafeArea(.all)
                
                List {
                    Section(header: Text("Host Information").foregroundColor(.gray)) {
                        SpecRow(label: "Hostname", value: stats.hostname)
                        SpecRow(label: "OS & Kernel", value: stats.os_name)
                        SpecRow(label: "Architecture", value: stats.arch)
                        SpecRow(label: "Local IP", value: stats.local_ip)
                        SpecRow(label: "Uptime", value: stats.uptime_formatted)
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                    
                    Section(header: Text("Processor").foregroundColor(.gray)) {
                        SpecRow(label: "CPU Cores", value: "\(stats.cpu_count)")
                        SpecRow(label: "Load Averages", value: stats.load_avg.map { String(format: "%.2f", $0) }.joined(separator: ", "))
                        if let temp = stats.temperature_c {
                            SpecRow(label: "Thermal Sensor", value: String(format: "%.1f°C", temp))
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                    
                    Section(header: Text("Memory & Storage").foregroundColor(.gray)) {
                        SpecRow(label: "RAM Total", value: stats.memory.total_formatted)
                        SpecRow(label: "RAM Used", value: "\(stats.memory.used_formatted) (\(Int(stats.memory.usage_pct))%)")
                        SpecRow(label: "RAM Available", value: stats.memory.free_formatted)
                        SpecRow(label: "Disk Capacity", value: stats.disk.total_formatted)
                        SpecRow(label: "Disk Free", value: stats.disk.free_formatted)
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("System Specifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

struct SpecRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Safari View for Subdomain Previews
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.preferredBarTintColor = .black
        vc.preferredControlTintColor = .white
        return vc
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

extension URL: Identifiable {
    public var id: String { self.absoluteString }
}
