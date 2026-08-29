import Foundation
import SwiftUI
import Combine

class ServerManager: ObservableObject {
    static let shared = ServerManager()
    
    @Published var systemStats: SystemMetrics? = nil
    @Published var containers: [DockerContainerInfo] = []
    @Published var services: [ServiceHealthInfo] = []
    
    @Published var isLoading: Bool = false
    @Published var isRefreshing: Bool = false
    @Published var isPruning: Bool = false
    @Published var actingContainerId: String? = nil
    
    @Published var selectedContainerLogs: String? = nil
    @Published var selectedContainerName: String? = nil
    @Published var isLoadingLogs: Bool = false
    
    @Published var alertMessage: String? = nil
    @Published var showAlert: Bool = false
    
    // File Explorer State
    @Published var currentDirectory: ServerDirectoryListing? = nil
    @Published var isLoadingDirectory: Bool = false
    @Published var currentFileDetail: ServerFileDetail? = nil
    @Published var isLoadingFile: Bool = false
    @Published var isSavingFile: Bool = false
    
    private var refreshTimer: AnyCancellable?
    private let baseURL = "https://pkpmusic.pottapk.win"
    
    init() {}
    
    func startMonitoring() {
        fetchOverviewData()
        // Refresh every 12 seconds while on the tab
        refreshTimer?.cancel()
        refreshTimer = Timer.publish(every: 12.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshMetricsSilently()
            }
    }
    
    func stopMonitoring() {
        refreshTimer?.cancel()
        refreshTimer = nil
    }
    
    func fetchOverviewData() {
        isLoading = true
        let group = DispatchGroup()
        
        group.enter()
        fetchSystemTelemetry { group.leave() }
        
        group.enter()
        fetchContainers { group.leave() }
        
        group.enter()
        fetchServicesHealth { group.leave() }
        
        group.notify(queue: .main) {
            self.isLoading = false
            self.isRefreshing = false
        }
    }
    
    func refreshMetricsSilently() {
        guard !isLoading && !isRefreshing else { return }
        isRefreshing = true
        let group = DispatchGroup()
        
        group.enter()
        fetchSystemTelemetry { group.leave() }
        
        group.enter()
        fetchContainers { group.leave() }
        
        group.enter()
        fetchServicesHealth { group.leave() }
        
        group.notify(queue: .main) {
            self.isRefreshing = false
        }
    }
    
    // MARK: - API Calls
    
    func fetchSystemTelemetry(completion: (() -> Void)? = nil) {
        guard let url = URL(string: "\(baseURL)/admin/server/system") else {
            completion?()
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 8.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { completion?() }
            guard let data = data, error == nil else { return }
            do {
                let stats = try JSONDecoder().decode(SystemMetrics.self, from: data)
                DispatchQueue.main.async {
                    self.systemStats = stats
                }
            } catch {
                print("Error decoding system stats: \(error)")
            }
        }.resume()
    }
    
    func fetchContainers(completion: (() -> Void)? = nil) {
        guard let url = URL(string: "\(baseURL)/admin/server/containers") else {
            completion?()
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 8.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { completion?() }
            guard let data = data, error == nil else { return }
            do {
                let list = try JSONDecoder().decode([DockerContainerInfo].self, from: data)
                DispatchQueue.main.async {
                    self.containers = list
                }
            } catch {
                print("Error decoding containers: \(error)")
            }
        }.resume()
    }
    
    func fetchServicesHealth(completion: (() -> Void)? = nil) {
        guard let url = URL(string: "\(baseURL)/admin/server/services") else {
            completion?()
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 8.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { completion?() }
            guard let data = data, error == nil else { return }
            do {
                let list = try JSONDecoder().decode([ServiceHealthInfo].self, from: data)
                DispatchQueue.main.async {
                    self.services = list
                }
            } catch {
                print("Error decoding services health: \(error)")
            }
        }.resume()
    }
    
    // MARK: - Container Actions
    
    func performContainerAction(container: DockerContainerInfo, action: String) {
        actingContainerId = container.id
        guard let url = URL(string: "\(baseURL)/admin/server/containers/\(container.id)/action") else {
            actingContainerId = nil
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["action": action]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 15.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.actingContainerId = nil
                if let error = error {
                    self.alertMessage = "Failed to \(action) container: \(error.localizedDescription)"
                    self.showAlert = true
                    return
                }
                
                // Refresh containers list after action
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.fetchContainers()
                }
            }
        }.resume()
    }
    
    // MARK: - Container Logs
    
    func fetchContainerLogs(container: DockerContainerInfo, tail: Int = 150) {
        selectedContainerName = container.name
        selectedContainerLogs = nil
        isLoadingLogs = true
        
        guard let url = URL(string: "\(baseURL)/admin/server/containers/\(container.id)/logs?tail=\(tail)") else {
            isLoadingLogs = false
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoadingLogs = false
                guard let data = data, error == nil else {
                    self.selectedContainerLogs = "Failed to load logs: \(error?.localizedDescription ?? "Network Error")"
                    return
                }
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let logs = json["logs"] as? String {
                    self.selectedContainerLogs = logs.isEmpty ? "No logs output." : logs
                } else {
                    self.selectedContainerLogs = String(data: data, encoding: .utf8) ?? "Unreadable log output."
                }
            }
        }.resume()
    }
    
    // MARK: - Prune Docker
    
    func pruneDocker() {
        isPruning = true
        guard let url = URL(string: "\(baseURL)/admin/server/docker/prune") else {
            isPruning = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isPruning = false
                guard let data = data, error == nil else {
                    self.alertMessage = "Prune failed: \(error?.localizedDescription ?? "Unknown Error")"
                    self.showAlert = true
                    return
                }
                
                if let result = try? JSONDecoder().decode(ServerPruneResult.self, from: data) {
                    if result.success {
                        let saved = result.space_reclaimed_formatted ?? "0 B"
                        let cont = result.containers_deleted ?? 0
                        let img = result.images_deleted ?? 0
                        self.alertMessage = "Cleaned \(saved) space!\nRemoved \(cont) stopped containers & \(img) unused images."
                    } else {
                        self.alertMessage = "Prune error: \(result.error ?? "Unknown")"
                    }
                } else {
                    self.alertMessage = "Cleaned up Docker cache successfully!"
                }
                self.showAlert = true
                self.fetchSystemTelemetry()
                self.fetchContainers()
            }
        }.resume()
    }
    
    // MARK: - File Explorer Networking
    
    func fetchDirectory(path: String = "~", completion: (() -> Void)? = nil) {
        isLoadingDirectory = true
        guard let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/admin/server/fs/list?path=\(encodedPath)") else {
            isLoadingDirectory = false
            completion?()
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoadingDirectory = false
                defer { completion?() }
                guard let data = data, error == nil else {
                    self.alertMessage = "Failed to load directory: \(error?.localizedDescription ?? "Network Error")"
                    self.showAlert = true
                    return
                }
                
                do {
                    let listing = try JSONDecoder().decode(ServerDirectoryListing.self, from: data)
                    self.currentDirectory = listing
                } catch {
                    print("Error decoding directory listing: \(error)")
                }
            }
        }.resume()
    }
    
    func readFile(path: String, completion: (() -> Void)? = nil) {
        isLoadingFile = true
        currentFileDetail = nil
        guard let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/admin/server/fs/read?path=\(encodedPath)") else {
            isLoadingFile = false
            completion?()
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 12.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoadingFile = false
                defer { completion?() }
                guard let data = data, error == nil else {
                    self.alertMessage = "Failed to open file: \(error?.localizedDescription ?? "Network Error")"
                    self.showAlert = true
                    return
                }
                
                do {
                    let detail = try JSONDecoder().decode(ServerFileDetail.self, from: data)
                    self.currentFileDetail = detail
                } catch {
                    self.alertMessage = "Could not parse file content."
                    self.showAlert = true
                }
            }
        }.resume()
    }
    
    func writeFile(path: String, content: String, completion: ((Bool) -> Void)? = nil) {
        isSavingFile = true
        guard let url = URL(string: "\(baseURL)/admin/server/fs/write") else {
            isSavingFile = false
            completion?(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["path": path, "content": content]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 15.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isSavingFile = false
                if let error = error {
                    self.alertMessage = "Save failed: \(error.localizedDescription)"
                    self.showAlert = true
                    completion?(false)
                    return
                }
                
                self.alertMessage = "File saved successfully!"
                self.showAlert = true
                completion?(true)
            }
        }.resume()
    }
    
    func createFolder(path: String, name: String, completion: ((Bool) -> Void)? = nil) {
        guard let url = URL(string: "\(baseURL)/admin/server/fs/mkdir") else {
            completion?(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["path": path, "name": name]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.alertMessage = "Failed to create folder: \(error.localizedDescription)"
                    self.showAlert = true
                    completion?(false)
                    return
                }
                
                self.fetchDirectory(path: path)
                completion?(true)
            }
        }.resume()
    }
    
    func deleteItem(path: String, parentPath: String, completion: ((Bool) -> Void)? = nil) {
        guard let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/admin/server/fs/delete?path=\(encodedPath)") else {
            completion?(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.alertMessage = "Failed to delete: \(error.localizedDescription)"
                    self.showAlert = true
                    completion?(false)
                    return
                }
                
                self.fetchDirectory(path: parentPath)
                completion?(true)
            }
        }.resume()
    }
    
    func renameItem(oldPath: String, newName: String, parentPath: String, completion: ((Bool) -> Void)? = nil) {
        guard let url = URL(string: "\(baseURL)/admin/server/fs/rename") else {
            completion?(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["old_path": oldPath, "new_name": newName]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.alertMessage = "Failed to rename: \(error.localizedDescription)"
                    self.showAlert = true
                    completion?(false)
                    return
                }
                
                self.fetchDirectory(path: parentPath)
                completion?(true)
            }
        }.resume()
    }
}
