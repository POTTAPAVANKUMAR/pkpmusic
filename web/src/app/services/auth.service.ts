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
    this.api.getMe().subscribe({
      next: (user) => {
        if (user) {
          this.userSignal.set(user);
        } else {
          // Token invalid or expired
          this.logout();
        }
      },
      error: () => {
        this.logout();
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

  logout() {
    localStorage.removeItem('pkp_auth_token');
    this.tokenSignal.set(null);
    this.userSignal.set(null);
  }
}
