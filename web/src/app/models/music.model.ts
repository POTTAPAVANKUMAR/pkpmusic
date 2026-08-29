export interface User {
  id: number;
  email: string;
  username?: string;
  name?: string;
  profile_picture_url?: string;
  is_active?: boolean;
}

export interface AuthResponse {
  access_token: string;
  token_type: string;
}

export interface Song {
  id: string;
  title: string;
  artist: string;
  album?: string | null;
  album_id?: string | null;
  duration_ms?: number;
  cover_art_url?: string | null;
  downloaded?: boolean;
}

export interface FavoriteItem {
  id: number;
  user_id: number;
  song_id: string;
  song: Song;
}

export interface PlaylistItem {
  id: number;
  playlist_id: number;
  song_id: string;
  position: number;
  song: Song;
}

export interface UserPlaylist {
  id: number;
  name: string;
  description?: string | null;
  owner_id: number;
  items: PlaylistItem[];
}

export interface HistoryItem {
  id: number;
  user_id: number;
  song_id: string;
  played_at: string;
  song: Song;
}

export interface AlbumSearchResult {
  id: string;
  browseId?: string;
  title: string;
  artist: string;
  cover_art_url?: string | null;
}

export interface ArtistSearchResult {
  id: string;
  browseId?: string;
  artist: string;
  cover_art_url?: string | null;
}

export interface DashboardItem {
  id: string;
  title: string;
  subtitle?: string | null;
  image_url?: string | null;
  type: 'song' | 'playlist' | 'album' | 'artist' | 'mood';
}

export interface DashboardSection {
  title: string;
  items: DashboardItem[];
}

export interface LyricsResponse {
  lyrics: string;
  source: string;
  isSynced?: boolean;
}

export interface SyncedLyricLine {
  time: number; // in seconds
  text: string;
}

export interface ArtistDetail {
  name: string;
  description?: string | null;
  views?: string | null;
  subscribers?: string | null;
  thumbnails: any[];
  songs: Song[];
  albums: any[];
}

export interface AlbumDetail {
  title: string;
  description?: string;
  trackCount?: number;
  thumbnails: any[];
  songs: Song[];
}

export interface ServerTelemetry {
  temperature_c?: number;
  cpu_usage_pct?: number;
  memory?: {
    used_formatted: string;
    total_formatted: string;
    usage_pct: number;
  };
  disk?: {
    used_formatted: string;
    total_formatted: string;
    usage_pct: number;
  };
  uptime_formatted?: string;
}

export interface MLJobRun {
  id: number;
  status: string; // 'Success' | 'Running' | 'Failed'
  started_at: number;
  completed_at?: number | null;
  users_processed: number;
  recommendations_generated: number;
  error_message?: string | null;
}

export interface DockerContainerInfo {
  id: string;
  name: string;
  image: string;
  status: string;
  state: string;
  ports?: string;
}

export interface ServiceHealth {
  name: string;
  url: string;
  status: string;
  status_code?: number;
  latency_ms?: number;
}

