import { Injectable, signal, computed } from '@angular/core';
import { ApiService } from './api.service';
import { User } from '../models/music.model';

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private tokenSignal = signal<string | null>(localStorage.getItem('pkp_auth_token'));
  private userSignal = signal<User | null>(null);

  token = this.tokenSignal.asReadonly();
  currentUser = this.userSignal.asReadonly();
  isAuthenticated = computed(() => !!this.tokenSignal());

  constructor(private api: ApiService) {
    if (this.tokenSignal()) {
      this.loadCurrentUser();
    }
  }

  loadCurrentUser() {
    this.api.getMe().subscribe(user => {
      if (user) {
        this.userSignal.set(user);
      } else {
        // Fallback user if token is local session
        this.userSignal.set({
          id: 1,
          email: 'admin@pottapk.win',
          name: 'Pavan Kumar Potta',
          profile_picture_url: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=120&auto=format&fit=crop&q=80'
        });
      }
    });
  }

  setSession(token: string, user?: User) {
    localStorage.setItem('pkp_auth_token', token);
    this.tokenSignal.set(token);
    if (user) {
      this.userSignal.set(user);
    } else {
      this.loadCurrentUser();
    }
  }

  loginWithPasscode(passcode: string): boolean {
    if (passcode === '5139147720') {
      const mockToken = 'pkp_passcode_session_' + Date.now();
      this.setSession(mockToken, {
        id: 1,
        email: 'admin@pottapk.win',
        name: 'Pavan Kumar Potta',
        profile_picture_url: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=120&auto=format&fit=crop&q=80'
      });
      return true;
    }
    return false;
  }

  logout() {
    localStorage.removeItem('pkp_auth_token');
    this.tokenSignal.set(null);
    this.userSignal.set(null);
  }
}
