import { Injectable, signal } from '@angular/core';
import { SyncedLyricLine } from '../models/music.model';

@Injectable({
  providedIn: 'root'
})
export class LyricsService {
  parsedLines = signal<SyncedLyricLine[]>([]);
  activeLineIndex = signal<number>(-1);

  parseLRC(lrcText: string): SyncedLyricLine[] {
    if (!lrcText) {
      this.parsedLines.set([]);
      return [];
    }
    const lines = lrcText.split('\n');
    const result: SyncedLyricLine[] = [];
    const timeRegex = /\[(\d{2}):(\d{2})(?:\.(\d{2,3}))?\]/g;

    for (const rawLine of lines) {
      const trimmed = rawLine.trim();
      if (!trimmed) continue;

      let match;
      timeRegex.lastIndex = 0;
      const matches: number[] = [];

      while ((match = timeRegex.exec(trimmed)) !== null) {
        const min = parseInt(match[1], 10);
        const sec = parseInt(match[2], 10);
        const ms = match[3] ? parseInt(match[3].padEnd(3, '0').slice(0, 3), 10) : 0;
        matches.push(min * 60 + sec + ms / 1000);
      }

      const text = trimmed.replace(timeRegex, '').trim();
      if (text) {
        for (const time of matches) {
          result.push({ time, text });
        }
      }
    }

    const sorted = result.sort((a, b) => a.time - b.time);
    this.parsedLines.set(sorted);
    return sorted;
  }

  getActiveLyricIndex(lyrics: SyncedLyricLine[], currentTimeSec: number): number {
    if (!lyrics || lyrics.length === 0) return -1;
    let activeIdx = -1;
    for (let i = 0; i < lyrics.length; i++) {
      if (currentTimeSec >= lyrics[i].time) {
        activeIdx = i;
      } else {
        break;
      }
    }
    this.activeLineIndex.set(activeIdx);
    return activeIdx;
  }
}
