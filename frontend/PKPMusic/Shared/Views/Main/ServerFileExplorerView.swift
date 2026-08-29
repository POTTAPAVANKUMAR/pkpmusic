import SwiftUI

struct ServerFileExplorerView: View {
    @StateObject private var serverManager = ServerManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    
    @State private var currentPath: String = "~"
    @State private var showingEditorSheet: Bool = false
    @State private var editingFileContent: String = ""
    @State private var editingFilePath: String = ""
    @State private var editingFileName: String = ""
    
    @State private var showingNewFolderDialog: Bool = false
    @State private var newFolderName: String = ""
    
    @State private var showingNewFileDialog: Bool = false
    @State private var newFileName: String = ""
    
    @State private var itemToRename: ServerFileItem? = nil
    @State private var renameNewName: String = ""
    @State private var showingRenameDialog: Bool = false
    
    @State private var itemToDelete: ServerFileItem? = nil
    @State private var showingDeleteConfirmation: Bool = false
    
    @State private var searchFilter: String = ""
    
    var filteredItems: [ServerFileItem] {
        guard let items = serverManager.currentDirectory?.items else { return [] }
        if searchFilter.isEmpty { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchFilter) }
    }
    
    var body: some View {
        ZStack {
            themeManager.currentTheme.backgroundColor.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                
                // ── 1. Quick Shortcut Bookmarks ───────────────────────
                bookmarksBar
                
                // ── 2. Breadcrumbs & Path Navigator ───────────────────
                pathNavigationBar
                
                // ── 3. Search Bar ─────────────────────────────────────
                searchBar
                
                // ── 4. File / Directory List ──────────────────────────
                if serverManager.isLoadingDirectory {
                    Spacer()
                    ProgressView("Loading directory...")
                        .foregroundColor(.gray)
                    Spacer()
                } else if filteredItems.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "folder.badge.questionmark")
                            .font(.system(size: 44))
                            .foregroundColor(.gray.opacity(0.5))
                        Text(searchFilter.isEmpty ? "Directory is empty" : "No matching files")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredItems) { item in
                            ServerFileRow(
                                item: item,
                                onTap: { handleItemTap(item) },
                                onRename: {
                                    itemToRename = item
                                    renameNewName = item.name
                                    showingRenameDialog = true
                                },
                                onDelete: {
                                    itemToDelete = item
                                    showingDeleteConfirmation = true
                                }
                            )
                        }
                        .listRowBackground(Color.white.opacity(0.04))
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        serverManager.fetchDirectory(path: currentPath)
                    }
                }
            }
        }
        .navigationTitle("File Explorer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        newFolderName = ""
                        showingNewFolderDialog = true
                    }) {
                        Label("New Folder", systemImage: "folder.badge.plus")
                    }
                    
                    Button(action: {
                        newFileName = ""
                        showingNewFileDialog = true
                    }) {
                        Label("New File", systemImage: "doc.badge.plus")
                    }
                    
                    Button(action: {
                        serverManager.fetchDirectory(path: currentPath)
                    }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                }
            }
        }
        .onAppear {
            serverManager.fetchDirectory(path: currentPath)
        }
        .sheet(isPresented: $showingEditorSheet) {
            ServerFileEditorSheet(
                fileName: editingFileName,
                filePath: editingFilePath,
                fileContent: $editingFileContent,
                onSave: { newContent in
                    serverManager.writeFile(path: editingFilePath, content: newContent) { success in
                        if success {
                            showingEditorSheet = false
                            serverManager.fetchDirectory(path: currentPath)
                        }
                    }
                }
            )
        }
        .alert(isPresented: $showingNewFolderDialog) {
            Alert(
                title: Text("New Folder"),
                message: Text("Enter folder name"),
                primaryButton: .default(Text("Create")) {
                    if !newFolderName.trimmingCharacters(in: .whitespaces).isEmpty {
                        serverManager.createFolder(path: currentPath, name: newFolderName)
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .alert("New Folder", isPresented: $showingNewFolderDialog) {
            TextField("Folder name", text: $newFolderName)
            Button("Create") {
                if !newFolderName.trimmingCharacters(in: .whitespaces).isEmpty {
                    serverManager.createFolder(path: currentPath, name: newFolderName)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("New File", isPresented: $showingNewFileDialog) {
            TextField("File name (e.g. config.yml)", text: $newFileName)
            Button("Create & Edit") {
                if !newFileName.trimmingCharacters(in: .whitespaces).isEmpty {
                    let targetPath = (serverManager.currentDirectory?.current_path ?? currentPath) + "/" + newFileName
                    editingFileName = newFileName
                    editingFilePath = targetPath
                    editingFileContent = ""
                    showingEditorSheet = true
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Rename Item", isPresented: $showingRenameDialog) {
            TextField("New name", text: $renameNewName)
            Button("Rename") {
                if let item = itemToRename, !renameNewName.trimmingCharacters(in: .whitespaces).isEmpty {
                    serverManager.renameItem(oldPath: item.path, newName: renameNewName, parentPath: currentPath)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .actionSheet(isPresented: $showingDeleteConfirmation) {
            ActionSheet(
                title: Text("Delete \(itemToDelete?.name ?? "Item")?"),
                message: Text("Are you sure you want to delete this \(itemToDelete?.is_dir == true ? "folder and all its contents" : "file")? This action cannot be undone."),
                buttons: [
                    .destructive(Text("Delete")) {
                        if let item = itemToDelete {
                            serverManager.deleteItem(path: item.path, parentPath: currentPath)
                        }
                    },
                    .cancel()
                ]
            )
        }
    }
    
    // MARK: - 1. Bookmarks Bar
    private var bookmarksBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                BookmarkPill(title: "Home", icon: "house.fill", isSelected: currentPath == "~") {
                    navigateTo("~")
                }
                BookmarkPill(title: "PKPMusic", icon: "music.note", isSelected: currentPath.contains("pkpmusic-backend")) {
                    navigateTo("~/pkpmusic-backend")
                }
                BookmarkPill(title: "PiCloud", icon: "internaldrive.fill", isSelected: currentPath.contains("picloud")) {
                    navigateTo("~/picloud")
                }
                BookmarkPill(title: "Landing", icon: "globe", isSelected: currentPath.contains("landing")) {
                    navigateTo("~/landing")
                }
                BookmarkPill(title: "Root", icon: "externaldrive.fill", isSelected: currentPath == "/") {
                    navigateTo("/")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color.black.opacity(0.3))
    }
    
    // MARK: - 2. Path Navigation Bar
    private var pathNavigationBar: some View {
        HStack(spacing: 10) {
            // Up Button
            if let parent = serverManager.currentDirectory?.parent_path, !parent.isEmpty {
                Button(action: {
                    navigateTo(parent)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                        Text("Up")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.1))
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .cornerRadius(8)
                }
            }
            
            // Path text
            ScrollView(.horizontal, showsIndicators: false) {
                Text(serverManager.currentDirectory?.display_path ?? currentPath)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.vertical, 4)
            }
            
            Spacer()
            
            // Items count
            if let count = serverManager.currentDirectory?.item_count {
                Text("\(count) items")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.04))
    }
    
    // MARK: - 3. Search Bar
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 13))
            TextField("Search in folder...", text: $searchFilter)
                .font(.system(size: 13))
                .foregroundColor(.white)
            if !searchFilter.isEmpty {
                Button(action: { searchFilter = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 13))
                }
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.06))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
    
    // MARK: - Actions
    private func navigateTo(_ path: String) {
        currentPath = path
        searchFilter = ""
        serverManager.fetchDirectory(path: path)
    }
    
    private func handleItemTap(_ item: ServerFileItem) {
        if item.is_dir {
            navigateTo(item.path)
        } else {
            // Open file in Editor/Viewer
            editingFileName = item.name
            editingFilePath = item.path
            serverManager.readFile(path: item.path) {
                if let content = serverManager.currentFileDetail?.content {
                    editingFileContent = content
                    showingEditorSheet = true
                }
            }
        }
    }
}

// MARK: - Bookmark Pill Subview
struct BookmarkPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue.opacity(0.3) : Color.white.opacity(0.07))
            .foregroundColor(isSelected ? .cyan : .white)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.cyan.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
    }
}

// MARK: - Server File Row Subview
struct ServerFileRow: View {
    let item: ServerFileItem
    let onTap: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    
    var iconColor: Color {
        if item.is_dir {
            return .yellow
        }
        let ext = item.extension_type
        if [".yml", ".yaml", ".conf", ".ini", ".env"].contains(ext) {
            return .orange
        } else if [".py", ".sh", ".bash", ".js", ".ts", ".html", ".css", ".sql"].contains(ext) {
            return .cyan
        } else if [".log", ".txt", ".md", ".json"].contains(ext) {
            return .purple
        } else if [".png", ".jpg", ".jpeg", ".webp"].contains(ext) {
            return .pink
        } else if [".mp3", ".m4a", ".flac"].contains(ext) {
            return .green
        } else {
            return .gray
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
                    .frame(width: 28, alignment: .center)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        if !item.is_dir && !item.size_formatted.isEmpty {
                            Text(item.size_formatted)
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                        
                        if !item.modified_formatted.isEmpty {
                            Text(item.modified_formatted)
                                .font(.system(size: 11))
                                .foregroundColor(.gray.opacity(0.8))
                        }
                    }
                }
                
                Spacer()
                
                if item.is_dir {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundColor(.gray.opacity(0.6))
                }
            }
            .padding(.vertical, 6)
        }
        .contextMenu {
            if !item.is_dir {
                Button(action: onTap) {
                    Label("Edit / View", systemImage: "pencil")
                }
            }
            
            Button(action: onRename) {
                Label("Rename", systemImage: "pencil.and.outline")
            }
            
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            
            Button(action: onRename) {
                Label("Rename", systemImage: "pencil.and.outline")
            }
            .tint(.orange)
        }
    }
}

// MARK: - Server File Editor Sheet
struct ServerFileEditorSheet: View {
    let fileName: String
    let filePath: String
    @Binding var fileContent: String
    let onSave: (String) -> Void
    
    @Environment(\.presentationMode) var presentationMode
    @State private var isSaving: Bool = false
    @State private var hasChanges: Bool = false
    @State private var copied: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Header path bar
                    HStack {
                        Image(systemName: "doc.text")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        Text(filePath)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                        Spacer()
                        Text("\(fileContent.components(separatedBy: "\n").count) lines")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.06))
                    
                    // Code Editor Text Area
                    TextEditor(text: $fileContent)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black)
                        .onChange(of: fileContent) { _ in
                            hasChanges = true
                        }
                }
            }
            .navigationTitle(fileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: {
                        UIPasteboard.general.string = fileContent
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            copied = false
                        }
                    }) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .foregroundColor(.gray)
                    }
                    
                    Button(action: {
                        isSaving = true
                        onSave(fileContent)
                    }) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Save")
                                .fontWeight(.bold)
                                .foregroundColor(.cyan)
                        }
                    }
                }
            }
        }
    }
}
