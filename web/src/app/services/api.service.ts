import { Injectable } from '@angular/core';
import { HttpClient, HttpParams, HttpHeaders } from '@angular/common/http';
import { Observable, of } from 'rxjs';
import { catchError, map } from 'rxjs/operators';
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
  ArtistSearchResult,
  FavoriteItem,
  UserPlaylist,
  HistoryItem,
  MLJobRun,
  DockerContainerInfo,
  ServiceHealth
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

  register(username: string, email: string, password: string): Observable<User> {
    return this.http.post<User>(`${this.baseUrl}/auth/register`, { username, email, password });
  }

  forgotPassword(email: string): Observable<any> {
    return this.http.post(`${this.baseUrl}/auth/forgot-password`, { email });
  }

  verifyOtp(email: string, otp: string, new_password: string): Observable<any> {
    return this.http.post(`${this.baseUrl}/auth/verify-otp`, { email, otp, new_password });
  }

  getMe(): Observable<User | null> {
    return this.http.get<User>(`${this.baseUrl}/auth/me`, { headers: this.getAuthHeaders() }).pipe(
      catchError(() => of(null))
    );
  }

  // --- USER DASHBOARD (PERSONALIZED FOR LOGGED-IN USER) ---
  getDashboard(): Observable<DashboardSection[]> {
    return this.http.get<DashboardSection[]>(`${this.baseUrl}/dashboard/`, { headers: this.getAuthHeaders() }).pipe(
      catchError(err => {
        console.error('Error fetching user dashboard:', err);
        return of([]);
      })
    );
  }

  // --- GLOBAL EXPLORE ---
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

  // --- USER FAVORITES (LIBRARY) ---
  getFavorites(): Observable<Song[]> {
    return this.http.get<FavoriteItem[]>(`${this.baseUrl}/favorites/`, { headers: this.getAuthHeaders() }).pipe(
      map(items => items.map(f => f.song)),
      catchError(err => {
        console.error('Error fetching favorites:', err);
        return of([]);
      })
    );
  }

  addFavorite(songId: string): Observable<any> {
    return this.http.post(`${this.baseUrl}/favorites/`, { song_id: songId }, { headers: this.getAuthHeaders() });
  }

  // --- USER PLAYLISTS (LIBRARY) ---
  getPlaylists(): Observable<UserPlaylist[]> {
    return this.http.get<UserPlaylist[]>(`${this.baseUrl}/playlists/`, { headers: this.getAuthHeaders() }).pipe(
      catchError(err => {
        console.error('Error fetching playlists:', err);
        return of([]);
      })
    );
  }

  createPlaylist(name: string, description: string = ''): Observable<UserPlaylist> {
    return this.http.post<UserPlaylist>(`${this.baseUrl}/playlists/`, { name, description }, { headers: this.getAuthHeaders() });
  }

  addSongToPlaylist(playlistId: number, songId: string): Observable<any> {
    return this.http.post(`${this.baseUrl}/playlists/${playlistId}/items`, { song_id: songId, position: 0 }, { headers: this.getAuthHeaders() });
  }

  // --- USER LISTENING HISTORY ---
  getHistory(): Observable<Song[]> {
    return this.http.get<HistoryItem[]>(`${this.baseUrl}/history/`, { headers: this.getAuthHeaders() }).pipe(
      map(items => items.map(h => h.song)),
      catchError(err => {
        console.error('Error fetching history:', err);
        return of([]);
      })
    );
  }

  recordHistory(songId: string): Observable<any> {
    const timestamp = new Date().toISOString();
    return this.http.post(`${this.baseUrl}/history/`, { song_id: songId, played_at: timestamp }, { headers: this.getAuthHeaders() });
  }

  // --- BOOKMARKS ---
  addBookmark(itemId: string, itemType: string, title: string, coverArtUrl?: string): Observable<any> {
    const body = {
      item_id: itemId,
      item_type: itemType,
      title: title,
      cover_art_url: coverArtUrl || null
    };
    return this.http.post(`${this.baseUrl}/bookmarks/`, body, { headers: this.getAuthHeaders() });
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
      map(items => items.map(a => ({
        id: a.browseId || (a as any).id,
        browseId: a.browseId,
        title: a.title,
        artist: a.artist,
        cover_art_url: a.cover_art_url
      }))),
      catchError(() => of([]))
    );
  }

  searchArtists(query: string): Observable<ArtistSearchResult[]> {
    const params = new HttpParams().set('query', query);
    return this.http.get<ArtistSearchResult[]>(`${this.baseUrl}/search/yt/artists`, { params, headers: this.getAuthHeaders() }).pipe(
      map(items => items.map(a => ({
        id: a.browseId || (a as any).id,
        browseId: a.browseId,
        artist: a.artist,
        cover_art_url: a.cover_art_url
      }))),
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
    return `${this.baseUrl}/stream/yt/${videoId}?quality=${quality}&proxy=true`;
  }

  downloadAudioBlob(videoId: string): Observable<Blob> {
    return this.http.get(`${this.baseUrl}/stream/yt/${videoId}?proxy=true`, { responseType: 'blob' });
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

  // --- SERVER TELEMETRY & MANAGEMENT ---
  getServerTelemetry(): Observable<ServerTelemetry> {
    return this.http.get<ServerTelemetry>(`${this.baseUrl}/admin/server/system`, { headers: this.getAuthHeaders() }).pipe(
      catchError(() => of({}))
    );
  }

  getServerContainers(): Observable<DockerContainerInfo[]> {
    return this.http.get<DockerContainerInfo[]>(`${this.baseUrl}/admin/server/containers`, { headers: this.getAuthHeaders() }).pipe(
      catchError(() => of([]))
    );
  }

  getServicesHealth(): Observable<ServiceHealth[]> {
    return this.http.get<ServiceHealth[]>(`${this.baseUrl}/admin/server/services`, { headers: this.getAuthHeaders() }).pipe(
      catchError(() => of([]))
    );
  }

  // --- AI / ML PIPELINE & ANALYTICS ---
  getMLMetrics(): Observable<MLJobRun[]> {
    return this.http.get<MLJobRun[]>(`${this.baseUrl}/admin/jobs/ml/metrics`, { headers: this.getAuthHeaders() }).pipe(
      catchError(() => of([]))
    );
  }

  triggerMLJob(): Observable<{ message: string }> {
    return this.http.post<{ message: string }>(`${this.baseUrl}/admin/jobs/ml/trigger`, {}, { headers: this.getAuthHeaders() });
  }
}

