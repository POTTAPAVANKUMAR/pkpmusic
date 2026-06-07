import SwiftUI

struct ChatDetailView: View {
    let friend: ChatUser
    @ObservedObject var chatManager: ChatManager
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var audioManager = AudioPlayerManager.shared
    
    @State private var messageText = ""
    @State private var showWebAnimation = false
    
    // Notification observer for new messages
    let pub = NotificationCenter.default.publisher(for: NSNotification.Name("NewChatMessage"))
    
    var body: some View {
        ZStack {
            Theme.spiderBlack.edgesIgnoringSafeArea(.all)
            
            VStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            let history = chatManager.messages[friend.id] ?? []
                            ForEach(history) { msg in
                                MessageBubble(message: msg, isMe: msg.senderId != friend.id)
                                    .id(msg.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: chatManager.messages[friend.id]?.count) { _ in
                        if let last = chatManager.messages[friend.id]?.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onReceive(pub) { notification in
                        if let msg = notification.object as? ChatMessage {
                            // If this message belongs to this conversation
                            if msg.senderId == friend.id || msg.receiverId == friend.id {
                                var current = chatManager.messages[friend.id] ?? []
                                // Prevent duplicates
                                if !current.contains(where: { $0.id == msg.id || ($0.timestamp == msg.timestamp && $0.content == msg.content) }) {
                                    current.append(msg)
                                    chatManager.messages[friend.id] = current
                                    
                                    // Trigger Spiderman web animation if it's an incoming message
                                    if msg.senderId == friend.id {
                                        triggerWebAnimation()
                                    }
                                    
                                    withAnimation {
                                        proxy.scrollTo(msg.id, anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Input Area
                HStack {
                    // Quick Share Song Button (Mock logic for now, shares current playing song)
                    Button(action: {
                        if let currentSong = audioManager.currentSong {
                            chatManager.sendMessage(receiverId: friend.id, content: currentSong.id, messageType: "song_share")
                        }
                    }) {
                        Image(systemName: "music.note")
                            .font(.title2)
                            .foregroundColor(audioManager.currentSong != nil ? Theme.spiderRed : .gray)
                    }
                    .disabled(audioManager.currentSong == nil)
                    
                    TextField("Message...", text: $messageText)
                        .padding(10)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(20)
                        .foregroundColor(.white)
                    
                    Button(action: {
                        guard !messageText.isEmpty else { return }
                        chatManager.sendMessage(receiverId: friend.id, content: messageText, messageType: "text")
                        messageText = ""
                    }) {
                        Image(systemName: "paperplane.fill")
                            .font(.title2)
                            .foregroundColor(Theme.spiderRed)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.8))
            }
            
            // Spiderman Web Animation Overlay
            if showWebAnimation {
                WebAnimationView()
                    .allowsHitTesting(false)
            }
        }
        .navigationTitle(friend.username)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let token = authManager.token {
                chatManager.fetchChatHistory(friendId: friend.id, token: token)
            }
        }
    }
    
    private func triggerWebAnimation() {
        showWebAnimation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showWebAnimation = false
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    let isMe: Bool
    
    var body: some View {
        HStack {
            if isMe { Spacer() }
            
            VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                if message.messageType == "song_share" {
                    // Song Share Card
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                        VStack(alignment: .leading) {
                            Text("Shared a Song")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Text("ID: \(message.content)") // Would normally resolve to Title/Artist
                                .font(.body).bold()
                                .foregroundColor(.white)
                        }
                    }
                    .padding(10)
                    .background(Color.purple.opacity(0.6))
                    .cornerRadius(12)
                    .onTapGesture {
                        // Play the song
                        AudioPlayerManager.shared.playSong(songId: message.content)
                    }
                } else {
                    // Standard Text
                    Text(message.content)
                        .padding(12)
                        .background(isMe ? Theme.spiderRed : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
                
                Text(formatDate(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            if !isMe { Spacer() }
        }
    }
    
    private func formatDate(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Spiderman Web String Animation
struct WebAnimationView: View {
    @State private var webLength: CGFloat = 0
    @State private var opacity: Double = 1.0
    
    var body: some View {
        GeometryReader { geo in
            Path { path in
                path.move(to: CGPoint(x: geo.size.width / 2, y: -50))
                path.addLine(to: CGPoint(x: geo.size.width / 2, y: webLength))
            }
            .stroke(Color.white.opacity(0.6), lineWidth: 2)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    webLength = geo.size.height / 2
                }
                withAnimation(.easeOut(duration: 0.5).delay(1.0)) {
                    opacity = 0
                }
            }
            
            // Web impact splat
            Circle()
                .fill(Color.white.opacity(0.8))
                .frame(width: webLength > 0 ? 20 : 0, height: webLength > 0 ? 20 : 0)
                .position(x: geo.size.width / 2, y: webLength)
                .opacity(opacity)
        }
    }
}
