import { Injectable, signal, computed } from '@angular/core';
import { Song, SyncedLyricLine } from '../models/music.model';
import { ApiService } from './api.service';
import { StorageService } from './storage.service';
import { LyricsService } from './lyrics.service';

export type RepeatMode = 'off' | 'all' | 'one';

@Injectable({
  providedIn: 'root'
})
export class PlayerService {
  private audio: HTMLAudioElement;

  // Signals for Reactive UI State
  currentSong = signal<Song | null>(null);
  isPlaying = signal<boolean>(false);
  isLoading = signal<boolean>(false);
  currentTime = signal<number>(0);
  duration = signal<number>(0);
  queue = signal<Song[]>([]);
  currentIndex = signal<number>(-1);
  shuffle = signal<boolean>(false);
  repeat = signal<RepeatMode>('off');
  volume = signal<number>(0.8);
  isMuted = signal<boolean>(false);
  autoplay = signal<boolean>(true);

  // Synced Lyrics
  lyricsText = signal<string>('');
  lyricsSource = signal<string>('None');
  isSyncedLyrics = signal<boolean>(false);
  syncedLines = signal<SyncedLyricLine[]>([]);
  activeLyricIndex = signal<number>(-1);

  // Computed Progress & Repeat
  repeatMode = computed(() => this.repeat());
  progressPercent = computed(() => {
    const dur = this.duration();
    if (!dur) return 0;
    return Math.min(100, Math.max(0, (this.currentTime() / dur) * 100));
  });

  constructor(
    private api: ApiService,
    private storage: StorageService,
    private lyricsService: LyricsService
  ) {
    this.audio = new Audio();
    this.audio.preload = 'metadata';
    this.setupAudioListeners();
    this.setupMediaSession();
  }

  private setupAudioListeners(): void {
    this.audio.addEventListener('loadstart', () => this.isLoading.set(true));
    this.audio.addEventListener('canplay', () => this.isLoading.set(false));
    this.audio.addEventListener('waiting', () => this.isLoading.set(true));
    this.audio.addEventListener('playing', () => {
      this.isPlaying.set(true);
      this.isLoading.set(false);
    });
    this.audio.addEventListener('pause', () => this.isPlaying.set(false));
    
    this.audio.addEventListener('timeupdate', () => {
      const cur = this.audio.currentTime;
      this.currentTime.set(cur);

      if (this.isSyncedLyrics()) {
        const idx = this.lyricsService.getActiveLyricIndex(this.syncedLines(), cur);
        if (idx !== this.activeLyricIndex()) {
          this.activeLyricIndex.set(idx);
        }
      }
    });

    this.audio.addEventListener('loadedmetadata', () => {
      this.duration.set(this.audio.duration || 0);
    });

    this.audio.addEventListener('ended', () => {
      this.handleSongEnded();
    });

    this.audio.addEventListener('error', (e) => {
      console.warn('Audio playback error, trying next track:', e);
      this.isLoading.set(false);
      this.next();
    });
  }

  private setupMediaSession(): void {
    if ('mediaSession' in navigator) {
      navigator.mediaSession.setActionHandler('play', () => this.play());
      navigator.mediaSession.setActionHandler('pause', () => this.pause());
      navigator.mediaSession.setActionHandler('previoustrack', () => this.previous());
      navigator.mediaSession.setActionHandler('nexttrack', () => this.next());
      navigator.mediaSession.setActionHandler('seekto', (details) => {
        if (details.seekTime !== undefined) {
          this.seek(details.seekTime);
        }
      });
    }
  }

  private updateMediaSessionMetadata(song: Song): void {
    if ('mediaSession' in navigator) {
      navigator.mediaSession.metadata = new MediaMetadata({
        title: song.title,
        artist: song.artist,
        album: song.album || 'PKP Music',
        artwork: song.cover_art_url ? [
          { src: song.cover_art_url, sizes: '512x512', type: 'image/jpeg' }
        ] : []
      });
    }
  }

  async playSong(song: Song, newQueue?: Song[]): Promise<void> {
    this.isLoading.set(true);
    if (newQueue) {
      this.queue.set([...newQueue]);
      const idx = newQueue.findIndex(s => s.id === song.id);
      this.currentIndex.set(idx >= 0 ? idx : 0);
    } else {
      let q = this.queue();
      let idx = q.findIndex(s => s.id === song.id);
      if (idx === -1) {
        q = [...q, song];
        this.queue.set(q);
        idx = q.length - 1;
      }
      this.currentIndex.set(idx);
    }

    this.currentSong.set(song);
    this.storage.addToHistory(song);
    this.updateMediaSessionMetadata(song);

    // Check if song has offline audio cached in IndexedDB
    const offlineBlob = await this.storage.getOfflineAudioBlob(song.id);
    if (offlineBlob) {
      this.audio.src = URL.createObjectURL(offlineBlob);
    } else {
      const quality = this.storage.getAudioQuality();
      this.audio.src = this.api.getStreamUrl(song.id, quality);
    }

    try {
      await this.audio.play();
      this.isPlaying.set(true);
    } catch (e) {
      console.warn('Playback autoplay prevented by browser policy:', e);
    } finally {
      this.isLoading.set(false);
    }

    // Load Lyrics
    this.loadLyrics(song.id);
  }

  async play(): Promise<void> {
    if (!this.currentSong() && this.queue().length > 0) {
      this.playSong(this.queue()[0]);
      return;
    }
    try {
      await this.audio.play();
      this.isPlaying.set(true);
    } catch (e) {
      console.error('Play error:', e);
    }
  }

  pause(): void {
    this.audio.pause();
    this.isPlaying.set(false);
  }

  togglePlay(): void {
    if (this.isPlaying()) {
      this.pause();
    } else {
      this.play();
    }
  }

  seek(seconds: number): void {
    this.audio.currentTime = seconds;
    this.currentTime.set(seconds);
  }

  setVolume(vol: number): void {
    this.volume.set(vol);
    this.audio.volume = vol;
    if (vol === 0) this.isMuted.set(true);
    else this.isMuted.set(false);
  }

  toggleMute(): void {
    if (this.isMuted()) {
      this.audio.volume = this.volume();
      this.isMuted.set(false);
    } else {
      this.audio.volume = 0;
      this.isMuted.set(true);
    }
  }

  toggleShuffle(): void {
    this.shuffle.set(!this.shuffle());
  }

  toggleRepeat(): void {
    const current = this.repeat();
    if (current === 'off') this.repeat.set('all');
    else if (current === 'all') this.repeat.set('one');
    else this.repeat.set('off');
  }

  next(): void {
    const q = this.queue();
    if (q.length === 0) return;

    if (this.repeat() === 'one' && this.currentSong()) {
      this.seek(0);
      this.play();
      return;
    }

    let nextIdx = this.currentIndex() + 1;
    if (this.shuffle()) {
      nextIdx = Math.floor(Math.random() * q.length);
    }

    if (nextIdx < q.length) {
      this.currentIndex.set(nextIdx);
      this.playSong(q[nextIdx]);
    } else if (this.repeat() === 'all') {
      this.currentIndex.set(0);
      this.playSong(q[0]);
    } else if (this.autoplay() && this.currentSong()) {
      this.fetchAndQueueSongRadio(this.currentSong()!.id);
    }
  }

  playNext(): void {
    this.next();
  }

  previous(): void {
    if (this.currentTime() > 4) {
      this.seek(0);
      return;
    }

    const q = this.queue();
    if (q.length === 0) return;

    let prevIdx = this.currentIndex() - 1;
    if (prevIdx >= 0) {
      this.currentIndex.set(prevIdx);
      this.playSong(q[prevIdx]);
    } else {
      this.seek(0);
    }
  }

  playPrevious(): void {
    this.previous();
  }

  private handleSongEnded(): void {
    if (this.repeat() === 'one') {
      this.seek(0);
      this.play();
    } else {
      this.next();
    }
  }

  private fetchAndQueueSongRadio(videoId: string): void {
    this.api.getUpNext(videoId).subscribe(tracks => {
      if (tracks && tracks.length > 0) {
        const filtered = tracks.filter(t => !this.queue().some(q => q.id === t.id));
        if (filtered.length > 0) {
          this.queue.set([...this.queue(), ...filtered]);
          this.next();
        }
      }
    });
  }

  loadLyrics(videoId: string): void {
    this.lyricsText.set('');
    this.syncedLines.set([]);
    this.isSyncedLyrics.set(false);
    this.activeLyricIndex.set(-1);

    this.api.getLyrics(videoId).subscribe(res => {
      if (res && res.lyrics) {
        this.lyricsText.set(res.lyrics);
        this.lyricsSource.set(res.source || 'LRCLIB');
        if (res.isSynced || res.lyrics.includes('[')) {
          const parsed = this.lyricsService.parseLRC(res.lyrics);
          if (parsed.length > 0) {
            this.syncedLines.set(parsed);
            this.isSyncedLyrics.set(true);
          }
        }
      }
    });
  }

  addToQueue(song: Song): void {
    this.queue.set([...this.queue(), song]);
  }

  removeFromQueue(index: number): void {
    const q = [...this.queue()];
    q.splice(index, 1);
    this.queue.set(q);
    if (index === this.currentIndex()) {
      if (q.length > 0) {
        const newIdx = Math.min(index, q.length - 1);
        this.currentIndex.set(newIdx);
        this.playSong(q[newIdx]);
      } else {
        this.pause();
        this.currentSong.set(null);
      }
    }
  }

  clearQueue(): void {
    const cur = this.currentSong();
    if (cur) {
      this.queue.set([cur]);
      this.currentIndex.set(0);
    } else {
      this.queue.set([]);
      this.currentIndex.set(-1);
    }
  }
}
