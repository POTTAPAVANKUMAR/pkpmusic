import { Component, OnInit, OnDestroy, inject, ViewChild, ElementRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Music } from '../../services/music';

@Component({
  selector: 'app-player',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './player.html',
  styles: [`
    .player-bar {
      position: fixed;
      bottom: 0;
      left: 0;
      width: 100%;
      height: 80px;
      background: rgba(18, 18, 18, 0.95);
      backdrop-filter: blur(10px);
      border-top: 1px solid #333;
      display: flex;
      align-items: center;
      padding: 0 20px;
      z-index: 1000;
    }
    .song-info {
      display: flex;
      align-items: center;
      flex: 1;
    }
    .cover-art {
      width: 50px;
      height: 50px;
      border-radius: 8px;
      margin-right: 15px;
      object-fit: cover;
    }
    .title {
      font-weight: 600;
      color: white;
      font-size: 0.9rem;
    }
    .artist {
      font-size: 0.8rem;
      color: var(--text-secondary);
    }
    .controls {
      display: flex;
      align-items: center;
      gap: 20px;
      flex: 1;
      justify-content: center;
    }
    .control-btn {
      background: none;
      border: none;
      color: white;
      font-size: 1.5rem;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .play-btn {
      width: 40px;
      height: 40px;
      border-radius: 50%;
      background-color: var(--spider-red);
      color: white;
    }
    .play-btn:hover {
      background-color: var(--spider-neon-red);
      transform: scale(1.05);
    }
    .extra-controls {
      flex: 1;
      display: flex;
      justify-content: flex-end;
    }
    .progress-container {
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 3px;
      background: #333;
      cursor: pointer;
    }
    .progress-bar {
      height: 100%;
      background: var(--spider-red);
      width: 0%;
      transition: width 0.1s linear;
    }
  `]
})
export class Player implements OnInit, OnDestroy {
  @ViewChild('audioEl') audioElRef!: ElementRef<HTMLAudioElement>;
  
  currentSong: any = null;
  isPlaying = false;
  progress = 0;
  
  private musicService = inject(Music);
  private listener = (e: any) => this.loadSong(e.detail);

  ngOnInit() {
    window.addEventListener('playSong', this.listener);
  }

  ngOnDestroy() {
    window.removeEventListener('playSong', this.listener);
  }

  loadSong(song: any) {
    this.currentSong = song;
    const streamUrl = this.musicService.getStreamUrl(song.id);
    
    setTimeout(() => {
      const audio = this.audioElRef.nativeElement;
      audio.src = streamUrl;
      this.play();
    });
  }

  togglePlay() {
    if (this.isPlaying) this.pause();
    else this.play();
  }

  play() {
    const audio = this.audioElRef.nativeElement;
    if (!audio.src) return;
    audio.play().then(() => this.isPlaying = true).catch(err => console.error(err));
  }

  pause() {
    this.audioElRef.nativeElement.pause();
    this.isPlaying = false;
  }

  onTimeUpdate() {
    const audio = this.audioElRef.nativeElement;
    if (audio.duration) {
      this.progress = (audio.currentTime / audio.duration) * 100;
    }
  }

  seek(event: MouseEvent) {
    const container = event.currentTarget as HTMLElement;
    const rect = container.getBoundingClientRect();
    const percent = (event.clientX - rect.left) / rect.width;
    const audio = this.audioElRef.nativeElement;
    
    if (audio.duration) {
      audio.currentTime = percent * audio.duration;
    }
  }
}
