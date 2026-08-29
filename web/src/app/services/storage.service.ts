import { Injectable, signal } from '@angular/core';
import { Song, UserPlaylist } from '../models/music.model';
import { ApiService } from './api.service';

@Injectable({
  providedIn: 'root'
})
export class StorageService {
  private dbName = 'PKPMusicDB';
  private dbVersion = 1;
  private db: IDBDatabase | null = null;

  // Reactive signals for components
  likedSongs = signal<Song[]>([]);
  customPlaylists = signal<UserPlaylist[]>([]);
  history = signal<Song[]>([]);
  downloads = signal<Song[]>([]);

  constructor(private api: ApiService) {
    this.initDB().then(() => {
      this.refreshDownloads();
    });
  }

  // --- SYNC WITH USER BACKEND DATABASE ---
  syncUserData() {
    this.loadFavorites();
    this.loadPlaylists();
    this.loadHistory();
  }

  loadFavorites() {
    this.api.getFavorites().subscribe(songs => {
      this.likedSongs.set(songs);
    });
  }

  loadPlaylists() {
    this.api.getPlaylists().subscribe(pls => {
      this.customPlaylists.set(pls);
    });
  }

  loadHistory() {
    this.api.getHistory().subscribe(hist => {
      this.history.set(hist);
    });
  }

  private initDB(): Promise<IDBDatabase> {
    return new Promise((resolve, reject) => {
      if (this.db) return resolve(this.db);
      const request = indexedDB.open(this.dbName, this.dbVersion);

      request.onupgradeneeded = (e: any) => {
        const db = e.target.result;
        if (!db.objectStoreNames.contains('offline_songs')) {
          db.createObjectStore('offline_songs', { keyPath: 'id' });
        }
        if (!db.objectStoreNames.contains('audio_blobs')) {
          db.createObjectStore('audio_blobs', { keyPath: 'id' });
        }
      };

      request.onsuccess = (e: any) => {
        this.db = e.target.result;
        resolve(this.db!);
      };

      request.onerror = (e) => reject(e);
    });
  }

  // --- FAVORITES / LIKED SONGS ---
  toggleLikedSong(song: Song): void {
    const isLiked = this.isSongLiked(song.id);
    if (isLiked) {
      this.likedSongs.set(this.likedSongs().filter(s => s.id !== song.id));
    } else {
      this.likedSongs.set([song, ...this.likedSongs()]);
    }
    this.api.addFavorite(song.id).subscribe({
      next: () => this.loadFavorites(),
      error: () => this.loadFavorites()
    });
  }

  isSongLiked(songId: string): boolean {
    return this.likedSongs().some(f => f.id === songId);
  }

  // --- CUSTOM PLAYLISTS ---
  createPlaylist(name: string, description: string = ''): void {
    this.api.createPlaylist(name, description).subscribe(() => {
      this.loadPlaylists();
    });
  }

  deletePlaylist(playlistId: number): void {
    this.customPlaylists.set(this.customPlaylists().filter(p => p.id !== playlistId));
    this.api.deletePlaylist(playlistId).subscribe({
      next: () => this.loadPlaylists(),
      error: () => this.loadPlaylists()
    });
  }

  removeSongFromPlaylist(playlistId: number, songId: string): void {
    this.api.removeSongFromPlaylist(playlistId, songId).subscribe({
      next: () => this.loadPlaylists(),
      error: () => this.loadPlaylists()
    });
  }

  // --- HISTORY ---
  addToHistory(song: Song): void {
    // Optimistically update signal
    const cur = this.history().filter(h => h.id !== song.id);
    this.history.set([song, ...cur]);

    // Record on backend for the user
    this.api.recordHistory(song.id).subscribe({
      next: () => {},
      error: (err) => console.warn('Error recording history to server:', err)
    });
  }

  // --- OFFLINE AUDIO (INDEXEDDB) ---
  async saveOfflineSong(song: Song, audioBlob: Blob): Promise<boolean> {
    const db = await this.initDB();
    return new Promise((resolve, reject) => {
      const tx = db.transaction(['offline_songs', 'audio_blobs'], 'readwrite');
      tx.objectStore('offline_songs').put({ ...song, downloaded: true });
      tx.objectStore('audio_blobs').put({ id: song.id, blob: audioBlob });
      tx.oncomplete = () => {
        this.refreshDownloads();
        resolve(true);
      };
      tx.onerror = (e) => reject(e);
    });
  }

  async refreshDownloads(): Promise<void> {
    const db = await this.initDB();
    const tx = db.transaction('offline_songs', 'readonly');
    const req = tx.objectStore('offline_songs').getAll();
    req.onsuccess = () => {
      this.downloads.set(req.result || []);
    };
  }

  async getOfflineAudioBlob(songId: string): Promise<Blob | null> {
    const db = await this.initDB();
    return new Promise((resolve, reject) => {
      const tx = db.transaction('audio_blobs', 'readonly');
      const req = tx.objectStore('audio_blobs').get(songId);
      req.onsuccess = () => resolve(req.result ? req.result.blob : null);
      req.onerror = (e) => reject(e);
    });
  }

  async removeDownload(songId: string): Promise<boolean> {
    const db = await this.initDB();
    return new Promise((resolve, reject) => {
      const tx = db.transaction(['offline_songs', 'audio_blobs'], 'readwrite');
      tx.objectStore('offline_songs').delete(songId);
      tx.objectStore('audio_blobs').delete(songId);
      tx.oncomplete = () => {
        this.refreshDownloads();
        resolve(true);
      };
      tx.onerror = (e) => reject(e);
    });
  }

  getAudioQuality(): string {
    return localStorage.getItem('pkp_audio_quality') || 'auto';
  }

  setAudioQuality(quality: string): void {
    localStorage.setItem('pkp_audio_quality', quality);
  }
}
