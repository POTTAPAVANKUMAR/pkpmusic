import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

export interface Song {
  id: string;
  title: string;
  artist: string;
  album?: string;
  duration_ms: number;
  cover_art_url?: string;
}

export interface DashboardItem {
  id: string;
  title: string;
  subtitle: string;
  image_url: string;
  type: string;
}

export interface DashboardSection {
  title: string;
  items: DashboardItem[];
}

@Injectable({
  providedIn: 'root'
})
export class Music {
  private http = inject(HttpClient);
  private readonly baseUrl = 'https://pkpmusic.pottapk.win';

  getDashboard(): Observable<DashboardSection[]> {
    return this.http.get<DashboardSection[]>(`${this.baseUrl}/dashboard/`);
  }

  getFavorites(): Observable<any[]> {
    return this.http.get<any[]>(`${this.baseUrl}/favorites/`);
  }

  addToFavorites(songId: string): Observable<any> {
    return this.http.post(`${this.baseUrl}/favorites/`, { song_id: songId });
  }

  getStreamUrl(songId: string): string {
    return `${this.baseUrl}/stream/yt/${songId}`;
  }
}
