import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { Auth } from '../../services/auth';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './login.html',
  styles: [`
    .login-container {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      padding: 20px;
    }
    .login-box {
      background-color: var(--spider-dark-grey);
      padding: 40px;
      border-radius: 16px;
      width: 100%;
      max-width: 400px;
      box-shadow: 0 10px 30px rgba(0,0,0,0.5);
    }
    .logo {
      font-size: 2rem;
      font-weight: 800;
      color: var(--spider-red);
      text-align: center;
      margin-bottom: 30px;
    }
    .error {
      color: var(--spider-neon-red);
      margin-bottom: 15px;
      text-align: center;
    }
  `]
})
export class Login {
  email = '';
  password = '';
  error = '';
  
  private auth = inject(Auth);
  private router = inject(Router);

  onSubmit() {
    if (!this.email || !this.password) return;
    
    this.auth.login({ username: this.email, password: this.password }).subscribe({
      next: () => {
        this.router.navigate(['/']);
      },
      error: (err) => {
        this.error = 'Invalid credentials';
        console.error(err);
      }
    });
  }
}
