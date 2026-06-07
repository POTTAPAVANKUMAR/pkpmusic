import CarPlay
import Combine
import Foundation

class CarPlayManager: NSObject, CPTemplateApplicationSceneDelegate {
    
    var interfaceController: CPInterfaceController?
    var cancellables = Set<AnyCancellable>()
    
    // Templates
    var tabBarTemplate: CPTabBarTemplate?
    var lyricsTemplate: CPInformationTemplate?
    var nowPlayingTemplate = CPNowPlayingTemplate.shared
    
    override init() {
        super.init()
        setupAudioPlayerSubscriptions()
    }
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        
        let playlistsTemplate = createPlaylistsTemplate()
        self.lyricsTemplate = createLyricsTemplate()
        
        tabBarTemplate = CPTabBarTemplate(templates: [playlistsTemplate, self.lyricsTemplate!])
        interfaceController.setRootTemplate(tabBarTemplate!, animated: true, completion: nil)
    }
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        self.interfaceController = nil
    }
    
    // MARK: - Template Creation
    
    func createPlaylistsTemplate() -> CPListTemplate {
        // We will fetch from NetworkManager
        let item = CPListItem(text: "Favorites", detailText: "Your liked songs")
        item.handler = { [weak self] item, completion in
            // Action to open favorites list
            completion()
        }
        
        let section = CPListSection(items: [item])
        let listTemplate = CPListTemplate(title: "Playlists", sections: [section])
        listTemplate.tabImage = UIImage(systemName: "music.note.list")
        return listTemplate
    }
    
    func createLyricsTemplate() -> CPInformationTemplate {
        // Experimental Lyrics template
        let infoItem = CPInformationItem(title: "No Song Playing", detail: "Start a song to see lyrics")
        let template = CPInformationTemplate(title: "Lyrics", layout: .leading, items: [infoItem], actions: [])
        template.tabImage = UIImage(systemName: "quote.bubble")
        return template
    }
    
    // MARK: - Audio Player Sync
    
    func setupAudioPlayerSubscriptions() {
        // This is a minimal implementation. 
        // In a real app, you would bind to AudioPlayerManager to update the CPNowPlayingTemplate
        // and fetch lyrics to update the Lyrics template.
        AudioPlayerManager.shared.$currentSong.sink { [weak self] song in
            guard let self = self, let song = song else { return }
            
            // Update Now Playing Template (CarPlay automatically handles basic info via MPRemoteCommandCenter,
            // but we can add specific CarPlay buttons if needed).
            
            // Fetch lyrics and update the Lyrics template if it's the active tab
            NetworkManager.shared.fetchLyrics(videoId: song.id) { lyricsResponse in
                if let lyrics = lyricsResponse?.lyrics {
                    self.updateLyricsTemplate(with: song.title, lyrics: lyrics)
                } else {
                    self.updateLyricsTemplate(with: song.title, lyrics: "No lyrics available.")
                }
            }
        }.store(in: &cancellables)
    }
    
    func updateLyricsTemplate(with title: String, lyrics: String) {
        guard let lyricsTemplate = self.lyricsTemplate else { return }
        
        // CarPlay might crash if detail text is too long!
        let truncatedLyrics = String(lyrics.prefix(1000)) 
        let infoItem = CPInformationItem(title: title, detail: truncatedLyrics)
        lyricsTemplate.items = [infoItem]
    }
}
