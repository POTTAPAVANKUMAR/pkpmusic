import SwiftUI

struct ChatListView: View {
    @StateObject private var chatManager = ChatManager()
    @StateObject private var authManager = AuthManager.shared
    
    @State private var searchText = ""
    @State private var isSearching = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.spiderBlack.edgesIgnoringSafeArea(.all)
                
                VStack {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search users...", text: $searchText)
                            .foregroundColor(.white)
                            .onChange(of: searchText) { newValue in
                                if newValue.count > 1 {
                                    chatManager.searchUsers(query: newValue, token: authManager.token ?? "")
                                } else {
                                    chatManager.searchResults = []
                                }
                            }
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                chatManager.searchResults = []
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            
                            // Search Results
                            if !chatManager.searchResults.isEmpty {
                                Text("Search Results")
                                    .font(.headline)
                                    .foregroundColor(Theme.spiderRed)
                                    .padding(.horizontal)
                                
                                ForEach(chatManager.searchResults) { user in
                                    HStack {
                                        Text(user.username)
                                            .foregroundColor(.white)
                                        Spacer()
                                        Button(action: {
                                            chatManager.sendRequest(friendId: user.id, token: authManager.token ?? "")
                                        }) {
                                            Text("Add Friend")
                                                .font(.caption)
                                                .padding(6)
                                                .background(Theme.spiderRed)
                                                .foregroundColor(.white)
                                                .cornerRadius(6)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            
                            // Pending Requests
                            if !chatManager.pendingRequests.isEmpty {
                                Text("Pending Requests")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal)
                                
                                ForEach(chatManager.pendingRequests) { req in
                                    HStack {
                                        Text(req.friend.username)
                                            .foregroundColor(.white)
                                        Spacer()
                                        Button(action: {
                                            chatManager.acceptRequest(friendId: req.friend.id, token: authManager.token ?? "")
                                        }) {
                                            Text("Accept")
                                                .font(.caption)
                                                .padding(6)
                                                .background(Color.green)
                                                .foregroundColor(.white)
                                                .cornerRadius(6)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            
                            // Friends List
                            Text("Friends")
                                .font(.headline)
                                .foregroundColor(Theme.spiderRed)
                                .padding(.horizontal)
                            
                            if chatManager.friends.isEmpty {
                                Text("No friends yet. Search for someone!")
                                    .foregroundColor(.gray)
                                    .padding()
                            } else {
                                ForEach(chatManager.friends) { friendship in
                                    NavigationLink(destination: ChatDetailView(friend: friendship.friend, chatManager: chatManager)) {
                                        HStack {
                                            Circle()
                                                .fill(Theme.spiderRed)
                                                .frame(width: 40, height: 40)
                                                .overlay(Text(String(friendship.friend.username.prefix(1).uppercased())).foregroundColor(.white))
                                            
                                            Text(friendship.friend.username)
                                                .foregroundColor(.white)
                                                .font(.body)
                                            Spacer()
                                        }
                                        .padding()
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(12)
                                        .padding(.horizontal)
                                    }
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let token = authManager.token {
                    chatManager.fetchFriends(token: token)
                    chatManager.fetchPendingRequests(token: token)
                    chatManager.connectWebSocket(token: token)
                }
            }
            .onDisappear {
                // If we want to disconnect when leaving the tab, we can. 
                // But it might be better to stay connected while app is open.
            }
        }
    }
}
