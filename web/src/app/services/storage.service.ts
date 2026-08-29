import { Injectable, signal } from '@angular/core';
import { Song, CustomPlaylist } from '../models/music.model';

@Injectable({
  providedIn: 'root'
})
export class StorageService {
  private dbName = 'PKPMusicDB';
  private dbVersion = 1;
  private db: IDBDatabase | null = null;

  // Reactive signals for components
  likedSongs = signal<Song[]>([]);
  customPlaylists = signal<CustomPlaylist[]>([]);
  history = signal<Song[]>([]);
  downloads = signal<Song[]>([]);

  constructor() {
    this.initDB().then(() => {
      this.refreshDownloads();
    });
    this.likedSongs.set(this.getFavorites());
    this.customPlaylists.set(this.getPlaylists());
    this.history.set(this.getHistory());
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
  getFavorites(): Song[] {
    const data = localStorage.getItem('pkp_favorites');
    return data ? JSON.parse(data) : [];
  }

  toggleLikedSong(song: Song): void {
    let favs = this.getFavorites();
    const idx = favs.findIndex(f => f.id === song.id);
    if (idx >= 0) {
      favs.splice(idx, 1);
    } else {
      favs.unshift(song);
    }
    localStorage.setItem('pkp_favorites', JSON.stringify(favs));
    this.likedSongs.set(favs);
  }

  isSongLiked(songId: string): boolean {
    return this.likedSongs().some(f => f.id === songId);
  }

  // --- CUSTOM PLAYLISTS ---
  getPlaylists(): CustomPlaylist[] {
    const data = localStorage.getItem('pkp_playlists');
    return data ? JSON.parse(data) : [];
  }

  createPlaylist(name: string, description: string = ''): CustomPlaylist {
    const playlists = this.getPlaylists();
    const newPlaylist: CustomPlaylist = {
      id: 'pl_' + Date.now(),
      name,
      description,
      created_at: Date.now(),
      tracks: []
    };
    playlists.push(newPlaylist);
    localStorage.setItem('pkp_playlists', JSON.stringify(playlists));
    this.customPlaylists.set(playlists);
    return newPlaylist;
  }

  deletePlaylist(playlistId: string): void {
    const playlists = this.getPlaylists().filter(p => p.id !== playlistId);
    localStorage.setItem('pkp_playlists', JSON.stringify(playlists));
    this.customPlaylists.set(playlists);
  }

  // --- HISTORY ---
  getHistory(): Song[] {
    const data = localStorage.getItem('pkp_history');
    return data ? JSON.parse(data) : [];
  }

  addToHistory(song: Song): Song[] {
    let hist = this.getHistory().filter(h => h.id !== song.id);
    hist.unshift(song);
    if (hist.length > 100) hist.pop();
    localStorage.setItem('pkp_history', JSON.stringify(hist));
    this.history.set(hist);
    return hist;
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
