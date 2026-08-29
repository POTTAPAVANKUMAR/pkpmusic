import { Component, OnInit, signal, computed, effect } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from './services/api.service';
import { StorageService } from './services/storage.service';
import { PlayerService } from './services/player.service';
import { Song, DashboardSection, DashboardItem, ArtistDetail, AlbumDetail, CustomPlaylist, ServerTelemetry, SyncedLyricLine } from './models/music.model';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './app.html',
  styleUrl: './app.css'
})
export class App implements OnInit {
  // Navigation State
  activeTab = signal<string>('home');

  // Search State
  searchQuery = signal<string>('');
  searchSuggestions = signal<string[]>([]);
  showSuggestions = signal<boolean>(false);
  searchFilter = signal<'all' | 'songs' | 'albums' | 'artists'>('all');
  searchSongsList = signal<Song[]>([]);
  searchAlbumsList = signal<any[]>([]);
  searchArtistsList = signal<any[]>([]);
  isSearching = signal<boolean>(false);

  // Home & Explore Feed
  exploreSections = signal<DashboardSection[]>([]);
  isLoadingExplore = signal<boolean>(true);

  // Library State
  favorites = signal<Song[]>([]);
  playlists = signal<CustomPlaylist[]>([]);
  history = signal<Song[]>([]);
  downloads = signal<Song[]>([]);

  // Details
  currentDetail = signal<AlbumDetail | null>(null);
  currentArtist = signal<ArtistDetail | null>(null);

  // Modals & Drawers
  isFullscreenOpen = signal<boolean>(false);
  isLyricsOpen = signal<boolean>(false);
  isQueueOpen = signal<boolean>(false);
  isCreatePlaylistOpen = signal<boolean>(false);
  isSettingsOpen = signal<boolean>(false);
  newPlaylistName = signal<string>('');
  newPlaylistDesc = signal<string>('');

  // Settings
  audioQuality = signal<string>('auto');

  // Server Telemetry
  telemetry = signal<ServerTelemetry>({});

  // Toast System
  toasts = signal<{ id: number; message: string }[]>([]);

  constructor(
    public player: PlayerService,
    private api: ApiService,
    private storage: StorageService
  ) {}

  ngOnInit(): void {
    this.loadExploreFeed();
    this.refreshLibrary();
    this.fetchTelemetry();
    this.audioQuality.set(this.storage.getAudioQuality());

    // Poll telemetry periodically
    setInterval(() => this.fetchTelemetry(), 6000);
  }

  // --- NAVIGATION ---
  switchView(tab: string): void {
    this.activeTab.set(tab);
    if (tab === 'favorites' || tab === 'playlists' || tab === 'history' || tab === 'downloads') {
      this.refreshLibrary();
    }
  }

  // --- EXPLORE & HOME ---
  loadExploreFeed(): void {
    this.isLoadingExplore.set(true);
    this.api.getExplore().subscribe(sections => {
      this.exploreSections.set(sections || []);
      this.isLoadingExplore.set(false);
    });
  }

  // --- SEARCH ---
  onSearchInput(val: string): void {
    this.searchQuery.set(val);
    if (val.trim().length > 1) {
      this.api.getSearchSuggestions(val.trim()).subscribe(suggs => {
        this.searchSuggestions.set(suggs || []);
        this.showSuggestions.set(suggs && suggs.length > 0);
      });
    } else {
      this.searchSuggestions.set([]);
      this.showSuggestions.set(false);
    }
  }

  selectSuggestion(sugg: string): void {
    this.searchQuery.set(sugg);
    this.showSuggestions.set(false);
    this.executeSearch();
  }

  executeSearch(): void {
    const q = this.searchQuery().trim();
    if (!q) return;
    this.showSuggestions.set(false);
    this.isSearching.set(true);
    this.switchView('search');

    this.api.searchSongs(q).subscribe(songs => {
      this.searchSongsList.set(songs || []);
      this.isSearching.set(false);
    });

    this.api.searchAlbums(q).subscribe(albums => {
      this.searchAlbumsList.set(albums || []);
    });

    this.api.searchArtists(q).subscribe(artists => {
      this.searchArtistsList.set(artists || []);
    });
  }

  setFilter(filter: 'all' | 'songs' | 'albums' | 'artists'): void {
    this.searchFilter.set(filter);
  }

  // --- ALBUM / ARTIST / PLAYLIST NAVIGATION ---
  openAlbum(browseId: string): void {
    this.api.getAlbum(browseId).subscribe(album => {
      if (album) {
        this.currentDetail.set(album);
        this.switchView('detail');
      }
    });
  }

  openArtist(channelId: string): void {
    this.api.getArtist(channelId).subscribe(artist => {
      if (artist) {
        this.currentArtist.set(artist);
        this.switchView('artist');
      }
    });
  }

  openMoodPlaylists(params: string): void {
    this.api.getMoodPlaylists(params).subscribe(items => {
      if (items && items.length > 0) {
        const formattedTracks: Song[] = items.filter(i => i.type === 'song').map(i => ({
          id: i.id,
          title: i.title,
          artist: i.subtitle || 'Mood Mix',
          cover_art_url: i.image_url
        }));
        this.currentDetail.set({
          title: 'Mood Mix',
          trackCount: formattedTracks.length,
          thumbnails: [],
          songs: formattedTracks
        });
        this.switchView('detail');
      }
    });
  }

  openCustomPlaylist(playlist: CustomPlaylist): void {
    this.currentDetail.set({
      title: playlist.name,
      description: playlist.description,
      trackCount: playlist.tracks.length,
      thumbnails: [],
      songs: playlist.tracks
    });
    this.switchView('detail');
  }

  // --- PLAYBACK TRIGGERS ---
  playSong(song: Song, queue?: Song[]): void {
    this.player.playSong(song, queue);
  }

  playAll(songs: Song[]): void {
    if (songs && songs.length > 0) {
      this.player.playSong(songs[0], songs);
    }
  }

  shuffleAll(songs: Song[]): void {
    if (songs && songs.length > 0) {
      const shuffled = [...songs].sort(() => Math.random() - 0.5);
      this.player.playSong(shuffled[0], shuffled);
    }
  }

  playItem(item: DashboardItem): void {
    if (item.type === 'song') {
      this.playSong({
        id: item.id,
        title: item.title,
        artist: item.subtitle || 'Unknown',
        cover_art_url: item.image_url
      });
    } else if (item.type === 'album' || item.type === 'playlist') {
      this.openAlbum(item.id);
    } else if (item.type === 'artist') {
      this.openArtist(item.id);
    } else if (item.type === 'mood') {
      this.openMoodPlaylists(item.id);
    }
  }

  // --- FAVORITES & OFFLINE ---
  isFav(songId: string): boolean {
    return this.storage.isFavorite(songId);
  }

  toggleFav(song: Song, event?: Event): void {
    if (event) event.stopPropagation();
    if (this.isFav(song.id)) {
      this.storage.removeFavorite(song.id);
      this.showToast(`Removed "${song.title}" from Liked Songs`);
    } else {
      this.storage.saveFavorite(song);
      this.showToast(`Added "${song.title}" to Liked Songs ❤️`);
    }
    this.refreshLibrary();
  }

  toggleCurrentFav(): void {
    const cur = this.player.currentSong();
    if (cur) this.toggleFav(cur);
  }

  async downloadSong(song: Song, event?: Event): Promise<void> {
    if (event) event.stopPropagation();
    this.showToast(`Downloading "${song.title}" for offline listening...`);
    try {
      this.api.downloadAudioBlob(song.id).subscribe(async blob => {
        if (blob) {
          await this.storage.saveOfflineSong(song, blob);
          this.showToast(`Downloaded "${song.title}" offline 📥`);
          this.refreshLibrary();
        }
      });
    } catch (e) {
      this.showToast(`Download error: ${e}`);
    }
  }

  async deleteOfflineSong(songId: string, event?: Event): Promise<void> {
    if (event) event.stopPropagation();
    await this.storage.removeOfflineSong(songId);
    this.showToast('Removed offline song');
    this.refreshLibrary();
  }

  // --- PLAYLIST CREATION ---
  openCreatePlaylist(): void {
    this.newPlaylistName.set('');
    this.newPlaylistDesc.set('');
    this.isCreatePlaylistOpen.set(true);
  }

  handleCreatePlaylist(): void {
    const name = this.newPlaylistName().trim();
    if (!name) return;
    this.storage.createPlaylist(name, this.newPlaylistDesc().trim());
    this.isCreatePlaylistOpen.set(false);
    this.refreshLibrary();
    this.showToast(`Created playlist "${name}" ✨`);
  }

  deletePlaylist(playlistId: string, event?: Event): void {
    if (event) event.stopPropagation();
    this.storage.deletePlaylist(playlistId);
    this.refreshLibrary();
    this.showToast('Deleted playlist');
  }

  // --- LIBRARY REFRESH ---
  async refreshLibrary(): Promise<void> {
    this.favorites.set(this.storage.getFavorites());
    this.playlists.set(this.storage.getPlaylists());
    this.history.set(this.storage.getHistory());
    const off = await this.storage.getOfflineSongs();
    this.downloads.set(off);
  }

  // --- SERVER TELEMETRY ---
  fetchTelemetry(): void {
    this.api.getServerTelemetry().subscribe(telem => {
      if (telem) this.telemetry.set(telem);
    });
  }

  copySSH(): void {
    navigator.clipboard.writeText('ssh pavankumarpotta@192.168.1.151').then(() => {
      this.showToast('Copied SSH command to clipboard! 📋');
    });
  }

  // --- SEEK & VOLUME ---
  onSeek(event: any): void {
    const val = parseFloat(event.target.value);
    const dur = this.player.duration();
    if (dur > 0) {
      const targetSec = (val / 100) * dur;
      this.player.seek(targetSec);
    }
  }

  onVolume(event: any): void {
    const val = parseFloat(event.target.value);
    this.player.setVolume(val);
  }

  // --- MODAL TOGGLES ---
  toggleFullscreen(): void {
    this.isFullscreenOpen.set(!this.isFullscreenOpen());
  }

  toggleLyrics(): void {
    this.isLyricsOpen.set(!this.isLyricsOpen());
  }

  toggleQueue(): void {
    this.isQueueOpen.set(!this.isQueueOpen());
  }

  toggleSettings(): void {
    this.isSettingsOpen.set(!this.isSettingsOpen());
  }

  saveAudioQuality(quality: string): void {
    this.audioQuality.set(quality);
    this.storage.setAudioQuality(quality);
    this.showToast(`Audio quality set to: ${quality}`);
  }

  async clearAllOffline(): Promise<void> {
    await this.storage.clearAllOffline();
    this.refreshLibrary();
    this.showToast('Cleared all offline downloaded songs');
  }

  // --- HELPERS ---
  formatTime(seconds: number): string {
    if (!seconds || isNaN(seconds)) return '0:00';
    const m = Math.floor(seconds / 60);
    const s = Math.floor(seconds % 60);
    return `${m}:${s < 10 ? '0' : ''}${s}`;
  }

  showToast(msg: string): void {
    const id = Date.now();
    this.toasts.set([...this.toasts(), { id, message: msg }]);
    setTimeout(() => {
      this.toasts.set(this.toasts().filter(t => t.id !== id));
    }, 3000);
  }
}
