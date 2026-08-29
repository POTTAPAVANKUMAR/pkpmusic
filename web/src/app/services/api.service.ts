import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable, of } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { Song, DashboardSection, DashboardItem, LyricsResponse, ArtistDetail, AlbumDetail, ServerTelemetry } from '../models/music.model';

@Injectable({
  providedIn: 'root'
})
export class ApiService {
  // Use relative or absolute API URL
  private baseUrl = 'https://pkpmusic.pottapk.win';

  constructor(private http: HttpClient) {}

  // Explore & Dashboard
  getExplore(): Observable<DashboardSection[]> {
    return this.http.get<DashboardSection[]>(`${this.baseUrl}/dashboard/explore/`).pipe(
      catchError(err => {
        console.error('Error fetching explore:', err);
        return of([]);
      })
    );
  }

  getMoodPlaylists(params: string): Observable<DashboardItem[]> {
    return this.http.get<DashboardItem[]>(`${this.baseUrl}/moods/${encodeURIComponent(params)}`).pipe(
      catchError(() => of([]))
    );
  }

  // Search
  searchSongs(query: string): Observable<Song[]> {
    const params = new HttpParams().set('query', query);
    return this.http.get<Song[]>(`${this.baseUrl}/search/yt`, { params }).pipe(
      catchError(() => of([]))
    );
  }

  searchAlbums(query: string): Observable<any[]> {
    const params = new HttpParams().set('query', query);
    return this.http.get<any[]>(`${this.baseUrl}/search/yt/albums`, { params }).pipe(
      catchError(() => of([]))
    );
  }

  searchArtists(query: string): Observable<any[]> {
    const params = new HttpParams().set('query', query);
    return this.http.get<any[]>(`${this.baseUrl}/search/yt/artists`, { params }).pipe(
      catchError(() => of([]))
    );
  }

  getSearchSuggestions(query: string): Observable<string[]> {
    const params = new HttpParams().set('query', query);
    return this.http.get<string[]>(`${this.baseUrl}/search/suggestions`, { params }).pipe(
      catchError(() => of([]))
    );
  }

  // Stream URL
  getStreamUrl(videoId: string, quality: string = 'auto'): string {
    return `${this.baseUrl}/stream/yt/${videoId}?quality=${quality}`;
  }

  // Fetch Audio Blob for Offline Download
  downloadAudioBlob(videoId: string): Observable<Blob> {
    return this.http.get(`${this.baseUrl}/stream/yt/${videoId}`, { responseType: 'blob' });
  }

  // Lyrics
  getLyrics(videoId: string): Observable<LyricsResponse> {
    return this.http.get<LyricsResponse>(`${this.baseUrl}/lyrics/${videoId}`).pipe(
      catchError(err => {
        console.warn('Lyrics not found:', err);
        return of({ lyrics: '', source: 'None', isSynced: false });
      })
    );
  }

  // Artist Detail
  getArtist(channelId: string): Observable<ArtistDetail> {
    return this.http.get<ArtistDetail>(`${this.baseUrl}/artist/${channelId}`).pipe(
      catchError(err => {
        console.error('Error fetching artist:', err);
        return of({ name: 'Unknown Artist', thumbnails: [], songs: [], albums: [] });
      })
    );
  }

  // Album Detail
  getAlbum(browseId: string): Observable<AlbumDetail> {
    return this.http.get<AlbumDetail>(`${this.baseUrl}/album/${browseId}`).pipe(
      catchError(err => {
        console.error('Error fetching album:', err);
        return of({ title: 'Unknown Album', trackCount: 0, thumbnails: [], songs: [] });
      })
    );
  }

  // Up Next / Autoplay Radio
  getUpNext(videoId: string): Observable<Song[]> {
    return this.http.get<Song[]>(`${this.baseUrl}/upnext/${videoId}`).pipe(
      catchError(() => of([]))
    );
  }

  // Server Telemetry
  getServerTelemetry(): Observable<ServerTelemetry> {
    return this.http.get<ServerTelemetry>(`${this.baseUrl}/admin/server/system`).pipe(
      catchError(() => of({}))
    );
  }
}
