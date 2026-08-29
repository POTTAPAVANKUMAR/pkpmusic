import { Injectable, signal, computed, effect } from '@angular/core';
import { ApiService } from './api.service';
import { AuthService } from './auth.service';
import { ChatUser, Friendship, ChatMessage, Song } from '../models/music.model';

@Injectable({
  providedIn: 'root'
})
export class ChatService {
  private socket: WebSocket | null = null;
  private reconnectTimeout: any = null;
  private reconnectAttempts = 0;
  private readonly maxReconnectAttempts = 10;

  // Reactive signals
  friends = signal<Friendship[]>([]);
  pendingRequests = signal<Friendship[]>([]);
  searchResults = signal<ChatUser[]>([]);
  availableUsers = signal<ChatUser[]>([]);
  activeFriend = signal<ChatUser | null>(null);
  
  // friendId -> ChatMessage[]
  messages = signal<Record<number, ChatMessage[]>>({});
  unreadCounts = signal<Record<number, number>>({});
  
  isWsConnected = signal<boolean>(false);
  isLoadingHistory = signal<boolean>(false);
  isSearchingUsers = signal<boolean>(false);

  // Total unread messages across all friends + pending requests
  totalUnread = computed(() => {
    const unreadMap = this.unreadCounts();
    const sum = Object.values(unreadMap).reduce((acc, curr) => acc + curr, 0);
    return sum + this.pendingRequests().length;
  });

  constructor(
    private api: ApiService,
    private auth: AuthService
  ) {
    // Reconnect / disconnect WebSocket when auth state changes
    effect(() => {
      const token = this.auth.token();
      if (token) {
        this.initChatSession();
      } else {
        this.disconnectWebSocket();
      }
    });
  }

  // --- SESSION INITIALIZATION ---
  initChatSession() {
    this.loadFriends();
    this.loadPendingRequests();
    this.loadDiscoverUsers();
    this.connectWebSocket();
  }

  // --- WEBSOCKET CONNECTION & MESSAGING ---
  connectWebSocket() {
    const token = this.auth.token();
    if (!token) return;

    if (this.socket && (this.socket.readyState === WebSocket.OPEN || this.socket.readyState === WebSocket.CONNECTING)) {
      return;
    }

    try {
      const wsProto = this.api.baseUrl.startsWith('https') ? 'wss://' : 'ws://';
      const hostPart = this.api.baseUrl.replace(/^https?:\/\//, '');
      const wsUrl = `${wsProto}${hostPart}/ws/chat?token=${token}`;

      this.socket = new WebSocket(wsUrl);

      this.socket.onopen = () => {
        this.isWsConnected.set(true);
        this.reconnectAttempts = 0;
      };

      this.socket.onmessage = (event) => {
        try {
          const raw = JSON.parse(event.data);
          const msg: ChatMessage = {
            id: raw.id || Date.now(),
            sender_id: raw.sender_id,
            receiver_id: raw.receiver_id,
            content: raw.content,
            message_type: raw.message_type || 'text',
            timestamp: raw.timestamp || Date.now() / 1000
          };
          this.handleIncomingMessage(msg);
        } catch (e) {
          console.error('Failed to parse incoming WebSocket message:', e);
        }
      };

      this.socket.onclose = () => {
        this.isWsConnected.set(false);
        this.scheduleReconnect();
      };

      this.socket.onerror = (err) => {
        console.error('WebSocket encountered an error:', err);
        this.isWsConnected.set(false);
      };
    } catch (err) {
      console.error('Error establishing WebSocket connection:', err);
      this.scheduleReconnect();
    }
  }

  disconnectWebSocket() {
    if (this.reconnectTimeout) {
      clearTimeout(this.reconnectTimeout);
      this.reconnectTimeout = null;
    }
    if (this.socket) {
      this.socket.close();
      this.socket = null;
    }
    this.isWsConnected.set(false);
  }

  private scheduleReconnect() {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      return;
    }
    const delay = Math.min(1000 * Math.pow(1.5, this.reconnectAttempts), 15000);
    this.reconnectAttempts++;
    this.reconnectTimeout = setTimeout(() => {
      if (this.auth.isAuthenticated()) {
        this.connectWebSocket();
      }
    }, delay);
  }

  private handleIncomingMessage(msg: ChatMessage) {
    const myId = this.auth.currentUser()?.id;
    // Determine the partner (friend) id for this message
    const partnerId = msg.sender_id === myId ? msg.receiver_id : msg.sender_id;

    // Append to messages signal
    const curMap = { ...this.messages() };
    const curList = curMap[partnerId] ? [...curMap[partnerId]] : [];

    // Avoid duplicate message IDs
    if (!curList.some(m => m.id === msg.id && m.id > 0)) {
      curList.push(msg);
      curMap[partnerId] = curList;
      this.messages.set(curMap);
    }

    // Increment unread count if not currently chatting with this partner
    const active = this.activeFriend();
    if (!active || active.id !== partnerId) {
      if (msg.sender_id !== myId) {
        const unread = { ...this.unreadCounts() };
        unread[partnerId] = (unread[partnerId] || 0) + 1;
        this.unreadCounts.set(unread);
      }
    }
  }

  sendMessage(receiverId: number, content: string, messageType: string = 'text') {
    if (!content.trim()) return;

    const payload = {
      receiver_id: receiverId,
      content: content.trim(),
      message_type: messageType
    };

    if (this.socket && this.socket.readyState === WebSocket.OPEN) {
      this.socket.send(JSON.stringify(payload));
    } else {
      // Reconnect and send
      this.connectWebSocket();
      setTimeout(() => {
        if (this.socket && this.socket.readyState === WebSocket.OPEN) {
          this.socket.send(JSON.stringify(payload));
        }
      }, 500);
    }
  }

  shareSongWithFriend(receiverId: number, song: Song) {
    // Encodes rich song metadata into JSON string for high-fidelity chat playback
    const songPayload = JSON.stringify({
      id: song.id,
      title: song.title,
      artist: song.artist,
      cover_art_url: song.cover_art_url || null,
      duration_ms: song.duration_ms || 0
    });
    this.sendMessage(receiverId, songPayload, 'song_share');
  }

  // --- FRIEND & SOCIAL MANAGEMENT ---
  selectFriend(friend: ChatUser) {
    this.activeFriend.set(friend);
    
    // Clear unread for this friend
    const unread = { ...this.unreadCounts() };
    delete unread[friend.id];
    this.unreadCounts.set(unread);

    // Load history if not loaded yet
    this.loadChatHistory(friend.id);
  }

  loadFriends() {
    this.api.getFriends().subscribe({
      next: (list) => this.friends.set(list),
      error: (err) => console.error('Error fetching friends:', err)
    });
  }

  loadPendingRequests() {
    this.api.getPendingRequests().subscribe({
      next: (list) => this.pendingRequests.set(list),
      error: (err) => console.error('Error fetching pending requests:', err)
    });
  }

  loadDiscoverUsers() {
    this.api.getAllUsers().subscribe({
      next: (list) => this.availableUsers.set(list),
      error: () => this.availableUsers.set([])
    });
  }

  searchUsers(query: string) {
    const clean = query.trim();
    if (clean.length < 2) {
      this.searchResults.set([]);
      return;
    }
    this.isSearchingUsers.set(true);
    this.api.searchUsers(clean).subscribe({
      next: (results) => {
        this.searchResults.set(results);
        this.isSearchingUsers.set(false);
      },
      error: () => {
        this.searchResults.set([]);
        this.isSearchingUsers.set(false);
      }
    });
  }

  sendFriendRequest(friendId: number, callback?: () => void) {
    this.api.sendFriendRequest(friendId).subscribe({
      next: () => {
        this.loadPendingRequests();
        this.loadFriends();
        callback?.();
      },
      error: (err) => console.error('Error sending friend request:', err)
    });
  }

  acceptFriendRequest(friendId: number, callback?: () => void) {
    this.api.acceptFriendRequest(friendId).subscribe({
      next: () => {
        this.loadFriends();
        this.loadPendingRequests();
        callback?.();
      },
      error: (err) => console.error('Error accepting friend request:', err)
    });
  }

  loadChatHistory(friendId: number) {
    this.isLoadingHistory.set(true);
    this.api.getChatHistory(friendId).subscribe({
      next: (rawHistory) => {
        // Reverse descending backend order so oldest is at top, latest at bottom
        const chronological = [...rawHistory].reverse();
        const curMap = { ...this.messages() };
        curMap[friendId] = chronological;
        this.messages.set(curMap);
        this.isLoadingHistory.set(false);
      },
      error: () => {
        this.isLoadingHistory.set(false);
      }
    });
  }
}
