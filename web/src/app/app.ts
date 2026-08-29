import { Component, OnInit, signal, computed, effect } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from './services/api.service';
import { PlayerService } from './services/player.service';
import { StorageService } from './services/storage.service';
import { LyricsService } from './services/lyrics.service';
import { AuthService } from './services/auth.service';
import { 
  Song, 
  DashboardSection, 
  DashboardItem, 
  ArtistDetail, 
  AlbumDetail, 
  AlbumSearchResult, 
  ArtistSearchResult, 
  ServerTelemetry 
} from './models/music.model';

type AppTab = 'home' | 'explore' | 'library' | 'history' | 'offline' | 'server';
type SearchType = 'songs' | 'albums' | 'artists';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './app.html',
  styleUrls: ['./app.css']
})
export class App implements OnInit {
  // Tab State
  selectedTab = signal<AppTab>('home');
  
  // Strict Mobile App Auth State (Matching LoginView, RegisterView, ForgotPasswordView)
  authMode = signal<'login' | 'register' | 'forgot' | 'verifyOtp'>('login');
  loginEmail = signal<string>('');
  loginPassword = signal<string>('');
  
  registerUsername = signal<string>('');
  registerEmail = signal<string>('');
  registerPassword = signal<string>('');
  
  resetEmail = signal<string>('');
  resetOtp = signal<string>('');
  resetNewPassword = signal<string>('');

  authError = signal<string | null>(null);
  authSuccessMsg = signal<string | null>(null);
  authLoading = signal<boolean>(false);

  // Search State
  searchQuery = signal<string>('');
  isSearching = signal<boolean>(false);
  searchType = signal<SearchType>('songs');
  searchResults = signal<Song[]>([]);
  searchAlbumResults = signal<AlbumSearchResult[]>([]);
  searchArtistResults = signal<ArtistSearchResult[]>([]);
  searchSuggestions = signal<string[]>([]);
  showSuggestions = signal<boolean>(false);

  // Dashboard & Navigation Data
  dashboardSections = signal<DashboardSection[]>([]);
  dashboardLoading = signal<boolean>(false);
  dashboardError = signal<string | null>(null);

  // Category Pills
  categories = [
    { name: 'Telugu', icon: '🎵', query: 'telugu songs' },
    { name: 'English', icon: '🎧', query: 'english songs' },
    { name: 'Tamil', icon: '🎼', query: 'tamil songs' },
    { name: 'Hindi', icon: '📻', query: 'hindi songs' },
    { name: 'Pop', icon: '🎤', query: 'pop music' },
    { name: 'R&B', icon: '🎶', query: 'r&b music' },
    { name: 'Artists', icon: '👥', query: 'top artists' },
    { name: 'Albums', icon: '💿', query: 'top albums' }
  ];

  // Details Views
  selectedArtist = signal<ArtistDetail | null>(null);
  selectedAlbum = signal<AlbumDetail | null>(null);
  selectedMoodTitle = signal<string | null>(null);
  moodPlaylists = signal<DashboardItem[]>([]);
  detailLoading = signal<boolean>(false);

  // Sheets & Drawers
  showFullScreenPlayer = signal<boolean>(false);
  activePlayerSheet = signal<'lyrics' | 'queue' | 'related' | 'options' | null>(null);
  newPlaylistName = signal<string>('');
  showNewPlaylistModal = signal<boolean>(false);

  // Server Telemetry
  telemetry = signal<ServerTelemetry | null>(null);

  constructor(
    public auth: AuthService,
    public player: PlayerService,
    public storage: StorageService,
    public lyrics: LyricsService,
    private api: ApiService
  ) {
    // Load dashboard when authenticated
    effect(() => {
      if (this.auth.isAuthenticated()) {
        this.loadDashboard();
        this.loadTelemetry();
      }
    });
  }

  ngOnInit() {
    if (this.auth.isAuthenticated()) {
      this.loadDashboard();
      this.loadTelemetry();
      setInterval(() => {
        if (this.selectedTab() === 'server') {
          this.loadTelemetry();
        }
      }, 6000);
    }
  }

  // --- MOBILE APP AUTHENTICATION FLOWS (1:1 with iOS) ---
  handleLogin() {
    const email = this.loginEmail().trim().toLowerCase();
    const password = this.loginPassword();

    if (!email || !password) {
      this.authError.set('Please enter email and password');
      return;
    }

    this.authLoading.set(true);
    this.authError.set(null);
    this.authSuccessMsg.set(null);

    this.api.login(email, password).subscribe({
      next: (res) => {
        this.auth.setSession(res.access_token);
        this.authLoading.set(false);
      },
      error: (err) => {
        this.authLoading.set(false);
        this.authError.set(err.error?.detail || 'Invalid credentials');
      }
    });
  }

  handleRegister() {
    const username = this.registerUsername().trim();
    const email = this.registerEmail().trim().toLowerCase();
    const password = this.registerPassword();

    if (!username || !email || !password) {
      this.authError.set('Please fill out all fields');
      return;
    }

    this.authLoading.set(true);
    this.authError.set(null);
    this.authSuccessMsg.set(null);

    this.api.register(username, email, password).subscribe({
      next: () => {
        // Automatically login the user after successful registration
        this.api.login(email, password).subscribe({
          next: (res) => {
            this.auth.setSession(res.access_token);
            this.authLoading.set(false);
          },
          error: () => {
            this.authLoading.set(false);
            this.authMode.set('login');
            this.authSuccessMsg.set('Account created! Please sign in with your password.');
          }
        });
      },
      error: (err) => {
        this.authLoading.set(false);
        this.authError.set(err.error?.detail || 'Registration failed');
      }
    });
  }

  handleForgotPasswordSendOTP() {
    const email = this.resetEmail().trim().toLowerCase();
    if (!email) {
      this.authError.set('Please enter your account email');
      return;
    }

    this.authLoading.set(true);
    this.authError.set(null);

    this.api.forgotPassword(email).subscribe({
      next: () => {
        this.authLoading.set(false);
        this.authSuccessMsg.set('OTP sent to your email (or check server logs)');
        this.authMode.set('verifyOtp');
      },
      error: (err) => {
        this.authLoading.set(false);
        this.authError.set(err.error?.detail || 'Failed to request reset OTP');
      }
    });
  }

  handleVerifyOTPAndResetPassword() {
    const email = this.resetEmail().trim().toLowerCase();
    const otp = this.resetOtp().trim();
    const newPass = this.resetNewPassword();

    if (!email || !otp || !newPass) {
      this.authError.set('Please enter OTP and new password');
      return;
    }

    this.authLoading.set(true);
    this.authError.set(null);

    this.api.verifyOtp(email, otp, newPass).subscribe({
      next: () => {
        this.authLoading.set(false);
        this.authMode.set('login');
        this.authSuccessMsg.set('Password reset successfully! You can now sign in.');
      },
      error: (err) => {
        this.authLoading.set(false);
        this.authError.set(err.error?.detail || 'Invalid or expired OTP');
      }
    });
  }

  handleLogout() {
    this.auth.logout();
    this.player.pause();
  }

  // --- NAVIGATION & TABS ---
  setTab(tab: AppTab) {
    this.selectedTab.set(tab);
    this.selectedArtist.set(null);
    this.selectedAlbum.set(null);
    this.selectedMoodTitle.set(null);
    if (tab === 'server') {
      this.loadTelemetry();
    }
  }

  // --- DASHBOARD ---
  loadDashboard() {
    this.dashboardLoading.set(true);
    this.dashboardError.set(null);

    this.api.getExplore().subscribe({
      next: (sections) => {
        this.dashboardSections.set(sections);
        this.dashboardLoading.set(false);
      },
      error: (err) => {
        this.dashboardError.set('Failed to load music dashboard.');
        this.dashboardLoading.set(false);
      }
    });
  }

  // --- SEARCH ---
  onSearchInput(query: string) {
    this.searchQuery.set(query);
    if (query.trim().length > 1) {
      this.api.getSearchSuggestions(query).subscribe(suggs => {
        this.searchSuggestions.set(suggs.slice(0, 5));
        this.showSuggestions.set(true);
      });
    } else {
      this.searchSuggestions.set([]);
      this.showSuggestions.set(false);
    }
  }

  performSearch(query?: string) {
    const q = (query !== undefined ? query : this.searchQuery()).trim();
    if (!q) return;

    this.searchQuery.set(q);
    this.isSearching.set(true);
    this.showSuggestions.set(false);

    if (this.searchType() === 'songs') {
      this.api.searchSongs(q).subscribe(results => {
        this.searchResults.set(results);
      });
    } else if (this.searchType() === 'albums') {
      this.api.searchAlbums(q).subscribe(results => {
        this.searchAlbumResults.set(results);
      });
    } else if (this.searchType() === 'artists') {
      this.api.searchArtists(q).subscribe(results => {
        this.searchArtistResults.set(results);
      });
    }
  }

  clearSearch() {
    this.searchQuery.set('');
    this.isSearching.set(false);
    this.searchResults.set([]);
    this.searchAlbumResults.set([]);
    this.searchArtistResults.set([]);
    this.showSuggestions.set(false);
  }

  setSearchType(type: SearchType) {
    this.searchType.set(type);
    if (this.isSearching() && this.searchQuery()) {
      this.performSearch();
    }
  }

  // --- ITEM INTERACTIONS ---
  handleDashboardItemClick(item: DashboardItem) {
    if (item.type === 'song') {
      const song: Song = {
        id: item.id,
        title: item.title,
        artist: item.subtitle || 'Unknown Artist',
        cover_art_url: item.image_url
      };
      this.player.playSong(song);
      this.showFullScreenPlayer.set(true);
    } else if (item.type === 'artist') {
      this.openArtist(item.id);
    } else if (item.type === 'album') {
      this.openAlbum(item.id);
    } else if (item.type === 'mood') {
      this.openMood(item.id, item.title);
    }
  }

  openArtist(channelId: string) {
    this.detailLoading.set(true);
    this.selectedAlbum.set(null);
    this.selectedMoodTitle.set(null);
    this.api.getArtist(channelId).subscribe(artist => {
      this.selectedArtist.set(artist);
      this.detailLoading.set(false);
    });
  }

  openAlbum(browseId: string) {
    this.detailLoading.set(true);
    this.selectedArtist.set(null);
    this.selectedMoodTitle.set(null);
    this.api.getAlbum(browseId).subscribe(album => {
      this.selectedAlbum.set(album);
      this.detailLoading.set(false);
    });
  }

  openMood(params: string, title: string) {
    this.detailLoading.set(true);
    this.selectedArtist.set(null);
    this.selectedAlbum.set(null);
    this.selectedMoodTitle.set(title);
    this.api.getMoodPlaylists(params).subscribe(items => {
      this.moodPlaylists.set(items);
      this.detailLoading.set(false);
    });
  }

  // --- PLAYBACK HELPERS ---
  playSongNow(song: Song, queueList?: Song[]) {
    this.player.playSong(song, queueList);
    this.showFullScreenPlayer.set(true);
  }

  playAllSongs(songs: Song[]) {
    if (songs.length > 0) {
      this.player.playSong(songs[0], songs);
      this.showFullScreenPlayer.set(true);
    }
  }

  toggleSheet(sheet: 'lyrics' | 'queue' | 'related' | 'options') {
    if (this.activePlayerSheet() === sheet) {
      this.activePlayerSheet.set(null);
    } else {
      this.activePlayerSheet.set(sheet);
    }
  }

  // --- CUSTOM PLAYLISTS ---
  createPlaylist() {
    const name = this.newPlaylistName().trim();
    if (name) {
      this.storage.createPlaylist(name);
      this.newPlaylistName.set('');
      this.showNewPlaylistModal.set(false);
    }
  }

  // --- TELEMETRY ---
  loadTelemetry() {
    this.api.getServerTelemetry().subscribe(telem => {
      this.telemetry.set(telem);
    });
  }

  copySSHCommand() {
    navigator.clipboard.writeText('ssh pavankumarpotta@192.168.1.151');
    alert('SSH command copied to clipboard!');
  }

  formatTime(seconds: number): string {
    if (isNaN(seconds) || seconds < 0) return '0:00';
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs < 10 ? '0' : ''}${secs}`;
  }
}
