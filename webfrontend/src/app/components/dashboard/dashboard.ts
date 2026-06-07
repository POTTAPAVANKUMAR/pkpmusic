import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Music, DashboardSection } from '../../services/music';
import { Player } from '../player/player'; // Will inject player service later, for now we can just use a simple event

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './dashboard.html',
  styles: [`
    .dashboard-container {
      padding: 20px;
    }
    .section-title {
      font-size: 1.5rem;
      font-weight: 800;
      margin-top: 30px;
      margin-bottom: 15px;
    }
    .items-scroll {
      display: flex;
      overflow-x: auto;
      gap: 15px;
      padding-bottom: 15px;
      scrollbar-width: none; /* Firefox */
    }
    .items-scroll::-webkit-scrollbar {
      display: none; /* Safari and Chrome */
    }
    .card {
      min-width: 150px;
      max-width: 150px;
      cursor: pointer;
      transition: transform 0.2s;
    }
    .card:hover {
      transform: scale(1.05);
    }
    .card img {
      width: 150px;
      height: 150px;
      object-fit: cover;
      border-radius: 12px;
      box-shadow: 0 4px 10px rgba(0,0,0,0.3);
    }
    .card-title {
      font-weight: 600;
      font-size: 0.9rem;
      margin-top: 8px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .card-subtitle {
      font-size: 0.8rem;
      color: var(--text-secondary);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
  `]
})
export class Dashboard implements OnInit {
  sections: DashboardSection[] = [];
  private musicService = inject(Music);

  ngOnInit() {
    this.musicService.getDashboard().subscribe({
      next: (data) => {
        this.sections = data;
      },
      error: (err) => console.error('Failed to load dashboard', err)
    });
  }

  playItem(item: any) {
    if (item.type === 'song') {
      // Dispatch custom event to the player
      const event = new CustomEvent('playSong', { detail: item });
      window.dispatchEvent(event);
    }
  }
}
