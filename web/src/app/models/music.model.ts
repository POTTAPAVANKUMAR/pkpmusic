export interface User {
  id: number;
  email: string;
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

export interface AlbumSearchResult {
  id: string;
  title: string;
  artist: string;
  cover_art_url?: string | null;
}

export interface ArtistSearchResult {
  id: string;
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

export interface CustomPlaylist {
  id: string;
  name: string;
  description?: string;
  created_at: number;
  tracks: Song[];
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
