import { Injectable } from '@angular/core';
import { HttpClient, HttpParams, HttpHeaders } from '@angular/common/http';
import { Observable, of } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { 
  Song, 
  DashboardSection, 
  DashboardItem, 
  LyricsResponse, 
  ArtistDetail, 
  AlbumDetail, 
  ServerTelemetry, 
  User, 
  AuthResponse,
  AlbumSearchResult,
  ArtistSearchResult 
} from '../models/music.model';

@Injectable({
  providedIn: 'root'
})
export class ApiService {
  private baseUrl = 'https://pkpmusic.pottapk.win';

  constructor(private http: HttpClient) {}

  private getAuthHeaders(): HttpHeaders {
    const token = localStorage.getItem('pkp_auth_token');
    if (token) {
      return new HttpHeaders({
        'Authorization': `Bearer ${token}`
      });
    }
    return new HttpHeaders();
  }

  // --- AUTHENTICATION ---
  login(email: string, password: string): Observable<AuthResponse> {
    return this.http.post<AuthResponse>(`${this.baseUrl}/auth/login`, { email, password });
  }

  register(name: string, email: string, password: string): Observable<User> {
    return this.http.post<User>(`${this.baseUrl}/auth/register`, { name, email, password });
  }

  forgotPassword(email: string): Observable<any> {
    return this.http.post(`${this.baseUrl}/auth/forgot-password`, { email });
  }

  getMe(): Observable<User | null> {
    return this.http.get<User>(`${this.baseUrl}/auth/me`, { headers: this.getAuthHeaders() }).pipe(
      catchError(() => of(null))
    );
  }

  // --- DASHBOARD & EXPLORE ---
  getExplore(): Observable<DashboardSection[]> {
    return this.http.get<DashboardSection[]>(`${this.baseUrl}/dashboard/explore/`, { headers: this.getAuthHeaders() }).pipe(
      catchError(err => {
        console.error('Error fetching explore:', err);
        return of([]);
      })
    );
  }

  getMoodPlaylists(params: string): Observable<DashboardItem[]> {
    return this.http.get<DashboardItem[]>(`${this.baseUrl}/moods/${encodeURIComponent(params)}`, { headers: this.getAuthHeaders() }).pipe(
      catchError(() => of([]))
    );
  }

  // --- SEARCH ---
  searchSongs(query: string): Observable<Song[]> {
    const params = new HttpParams().set('query', query);
    return this.http.get<Song[]>(`${this.baseUrl}/search/yt`, { params, headers: this.getAuthHeaders() }).pipe(
      catchError(() => of([]))
    );
  }

  searchAlbums(query: string): Observable<AlbumSearchResult[]> {
    const params = new HttpParams().set('query', query);
    return this.http.get<AlbumSearchResult[]>(`${this.baseUrl}/search/yt/albums`, { params, headers: this.getAuthHeaders() }).pipe(
      catchError(() => of([]))
    );
  }

  searchArtists(query: string): Observable<ArtistSearchResult[]> {
    const params = new HttpParams().set('query', query);
    return this.http.get<ArtistSearchResult[]>(`${this.baseUrl}/search/yt/artists`, { params, headers: this.getAuthHeaders() }).pipe(
      catchError(() => of([]))
    );
  }

  getSearchSuggestions(query: string): Observable<string[]> {
    const params = new HttpParams().set('query', query);
    return this.http.get<string[]>(`${this.baseUrl}/search/suggestions`, { params, headers: this.getAuthHeaders() }).pipe(
      catchError(() => of([]))
    );
  }

  // --- STREAMING & DOWNLOADS ---
  getStreamUrl(videoId: string, quality: string = 'auto'): string {
    return `${this.baseUrl}/stream/yt/${videoId}?quality=${quality}`;
  }

  downloadAudioBlob(videoId: string): Observable<Blob> {
    return this.http.get(`${this.baseUrl}/stream/yt/${videoId}`, { responseType: 'blob' });
  }

  // --- LYRICS ---
  getLyrics(videoId: string): Observable<LyricsResponse> {
    return this.http.get<LyricsResponse>(`${this.baseUrl}/lyrics/${videoId}`, { headers: this.getAuthHeaders() }).pipe(
      catchError(err => {
        console.warn('Lyrics not found:', err);
        return of({ lyrics: '', source: 'None', isSynced: false });
      })
    );
  }

  // --- ARTIST & ALBUM ---
  getArtist(channelId: string): Observable<ArtistDetail> {
    return this.http.get<ArtistDetail>(`${this.baseUrl}/artist/${channelId}`, { headers: this.getAuthHeaders() }).pipe(
      catchError(err => {
        console.error('Error fetching artist:', err);
        return of({ name: 'Unknown Artist', thumbnails: [], songs: [], albums: [] });
      })
    );
  }

  getAlbum(browseId: string): Observable<AlbumDetail> {
    return this.http.get<AlbumDetail>(`${this.baseUrl}/album/${browseId}`, { headers: this.getAuthHeaders() }).pipe(
      catchError(err => {
        console.error('Error fetching album:', err);
        return of({ title: 'Unknown Album', trackCount: 0, thumbnails: [], songs: [] });
      })
    );
  }

  // --- UP NEXT / AUTOPLAY ---
  getUpNext(videoId: string): Observable<Song[]> {
    return this.http.get<Song[]>(`${this.baseUrl}/upnext/${videoId}`, { headers: this.getAuthHeaders() }).pipe(
      catchError(() => of([]))
    );
  }

  // --- SERVER TELEMETRY ---
  getServerTelemetry(): Observable<ServerTelemetry> {
    return this.http.get<ServerTelemetry>(`${this.baseUrl}/admin/server/system`).pipe(
      catchError(() => of({}))
    );
  }
}
