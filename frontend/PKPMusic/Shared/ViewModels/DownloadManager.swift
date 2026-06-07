import Foundation
import Combine

class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()
    
    @Published var downloadedSongs: [Song] = []
    @Published var activeDownloads: [String: Double] = [:] // songId -> progress (0.0 to 1.0)
    
    private var urlSession: URLSession!
    private let fileManager = FileManager.default
    
    // In-memory mapping of task to song ID
    private var downloadTasks: [Int: String] = [:]
    
    private let downloadsKey = "offline_songs.json"
    
    override init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: "com.pkpmusic.backgroundDownloads")
        self.urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        loadMetadata()
    }
    
    // MARK: - Paths
    private func getDocumentsDirectory() -> URL {
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func getMetadataFileURL() -> URL {
        return getDocumentsDirectory().appendingPathComponent(downloadsKey)
    }
    
    private func getLocalFileURL(for songId: String) -> URL {
        return getDocumentsDirectory().appendingPathComponent("\(songId).mp3")
    }
    
    // MARK: - Public API
    
    func isDownloaded(songId: String) -> Bool {
        return downloadedSongs.contains(where: { $0.id == songId }) && fileManager.fileExists(atPath: getLocalFileURL(for: songId).path)
    }
    
    func localURL(for songId: String) -> URL? {
        let url = getLocalFileURL(for: songId)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }
    
    func download(song: Song) {
        guard !isDownloaded(songId: song.id), activeDownloads[song.id] == nil else { return }
        
        guard let url = NetworkManager.shared.getStreamURL(for: song.id) else { return }
        var request = URLRequest(url: url)
        if let token = AuthManager.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let task = urlSession.downloadTask(with: request)
        downloadTasks[task.taskIdentifier] = song.id
        
        // Temporarily store song metadata in memory until download completes
        UserDefaults.standard.set(try? JSONEncoder().encode(song), forKey: "pending_song_\(song.id)")
        
        DispatchQueue.main.async {
            self.activeDownloads[song.id] = 0.0
        }
        
        task.resume()
    }
    
    func removeDownload(songId: String) {
        let url = getLocalFileURL(for: songId)
        try? fileManager.removeItem(at: url)
        
        DispatchQueue.main.async {
            self.downloadedSongs.removeAll { $0.id == songId }
            self.saveMetadata()
        }
    }
    
    // MARK: - Persistence
    
    private func saveMetadata() {
        if let data = try? JSONEncoder().encode(downloadedSongs) {
            try? data.write(to: getMetadataFileURL())
        }
    }
    
    private func loadMetadata() {
        if let data = try? Data(contentsOf: getMetadataFileURL()),
           let songs = try? JSONDecoder().decode([Song].self, from: data) {
            DispatchQueue.main.async {
                self.downloadedSongs = songs
            }
        }
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let songId = downloadTasks[downloadTask.taskIdentifier] else { return }
        
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            self.activeDownloads[songId] = max(0.01, progress)
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let songId = downloadTasks[downloadTask.taskIdentifier] else { return }
        let destinationURL = getLocalFileURL(for: songId)
        
        // Move the temp file to documents
        try? fileManager.removeItem(at: destinationURL) // Remove if exists
        do {
            try fileManager.moveItem(at: location, to: destinationURL)
            
            // Reconstruct the song and save metadata
            if let data = UserDefaults.standard.data(forKey: "pending_song_\(songId)"),
               let song = try? JSONDecoder().decode(Song.self, from: data) {
                
                DispatchQueue.main.async {
                    if !self.downloadedSongs.contains(where: { $0.id == song.id }) {
                        self.downloadedSongs.append(song)
                        self.saveMetadata()
                    }
                    self.activeDownloads.removeValue(forKey: songId)
                    UserDefaults.standard.removeObject(forKey: "pending_song_\(songId)")
                }
            }
        } catch {
            print("Error moving downloaded file: \(error)")
            DispatchQueue.main.async {
                self.activeDownloads.removeValue(forKey: songId)
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error, let songId = downloadTasks[task.taskIdentifier] {
            print("Download failed for \(songId): \(error)")
            DispatchQueue.main.async {
                self.activeDownloads.removeValue(forKey: songId)
            }
        }
        downloadTasks.removeValue(forKey: task.taskIdentifier)
    }
}
