import { Injectable } from '@angular/core';
import { Song, CustomPlaylist } from '../models/music.model';

@Injectable({
  providedIn: 'root'
})
export class StorageService {
  private dbName = 'PKPMusicDB';
  private dbVersion = 1;
  private db: IDBDatabase | null = null;

  constructor() {
    this.initDB();
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

  // --- FAVORITES ---
  getFavorites(): Song[] {
    const data = localStorage.getItem('pkp_favorites');
    return data ? JSON.parse(data) : [];
  }

  saveFavorite(song: Song): Song[] {
    let favs = this.getFavorites();
    if (!favs.some(f => f.id === song.id)) {
      favs.unshift(song);
      localStorage.setItem('pkp_favorites', JSON.stringify(favs));
    }
    return favs;
  }

  removeFavorite(songId: string): Song[] {
    let favs = this.getFavorites().filter(f => f.id !== songId);
    localStorage.setItem('pkp_favorites', JSON.stringify(favs));
    return favs;
  }

  isFavorite(songId: string): boolean {
    return this.getFavorites().some(f => f.id === songId);
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
    return newPlaylist;
  }

  addTrackToPlaylist(playlistId: string, track: Song): CustomPlaylist | undefined {
    const playlists = this.getPlaylists();
    const pl = playlists.find(p => p.id === playlistId);
    if (pl && !pl.tracks.some(t => t.id === track.id)) {
      pl.tracks.push(track);
      localStorage.setItem('pkp_playlists', JSON.stringify(playlists));
    }
    return pl;
  }

  removeTrackFromPlaylist(playlistId: string, songId: string): CustomPlaylist | undefined {
    const playlists = this.getPlaylists();
    const pl = playlists.find(p => p.id === playlistId);
    if (pl) {
      pl.tracks = pl.tracks.filter(t => t.id !== songId);
      localStorage.setItem('pkp_playlists', JSON.stringify(playlists));
    }
    return pl;
  }

  deletePlaylist(playlistId: string): CustomPlaylist[] {
    const playlists = this.getPlaylists().filter(p => p.id !== playlistId);
    localStorage.setItem('pkp_playlists', JSON.stringify(playlists));
    return playlists;
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
    return hist;
  }

  // --- INDEXED DB OFFLINE AUDIO ---
  async saveOfflineSong(song: Song, audioBlob: Blob): Promise<boolean> {
    const db = await this.initDB();
    return new Promise((resolve, reject) => {
      const tx = db.transaction(['offline_songs', 'audio_blobs'], 'readwrite');
      tx.objectStore('offline_songs').put({ ...song, downloaded: true });
      tx.objectStore('audio_blobs').put({ id: song.id, blob: audioBlob });
      tx.oncomplete = () => resolve(true);
      tx.onerror = (e) => reject(e);
    });
  }

  async getOfflineSongs(): Promise<Song[]> {
    const db = await this.initDB();
    return new Promise((resolve, reject) => {
      const tx = db.transaction('offline_songs', 'readonly');
      const req = tx.objectStore('offline_songs').getAll();
      req.onsuccess = () => resolve(req.result || []);
      req.onerror = (e) => reject(e);
    });
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

  async removeOfflineSong(songId: string): Promise<boolean> {
    const db = await this.initDB();
    return new Promise((resolve, reject) => {
      const tx = db.transaction(['offline_songs', 'audio_blobs'], 'readwrite');
      tx.objectStore('offline_songs').delete(songId);
      tx.objectStore('audio_blobs').delete(songId);
      tx.oncomplete = () => resolve(true);
      tx.onerror = (e) => reject(e);
    });
  }

  async clearAllOffline(): Promise<boolean> {
    const db = await this.initDB();
    return new Promise((resolve, reject) => {
      const tx = db.transaction(['offline_songs', 'audio_blobs'], 'readwrite');
      tx.objectStore('offline_songs').clear();
      tx.objectStore('audio_blobs').clear();
      tx.oncomplete = () => resolve(true);
      tx.onerror = (e) => reject(e);
    });
  }

  // --- AUDIO QUALITY PREF ---
  getAudioQuality(): string {
    return localStorage.getItem('pkp_audio_quality') || 'auto';
  }

  setAudioQuality(quality: string): void {
    localStorage.setItem('pkp_audio_quality', quality);
  }
}
