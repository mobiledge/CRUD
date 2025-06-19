import SwiftUI

struct BookmarkCRUDTestView: View {
    @State private var repository = {
        let repo = JSONFileCollectionResourceRepository<Bookmark>()
        repo.saveMany(upserting: Bookmark.mockCollection)
        return repo
    }()
    
    // Form state for creating/editing bookmarks
    @State private var title = ""
    @State private var urlText = ""
    @State private var tagText = ""
    @State private var selectedBookmark: Bookmark?
    @State private var isEditing = false
    
    // Test results display
    @State private var testResults = ""
    @State private var showingResults = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Bookmark Form Section
            VStack(alignment: .leading, spacing: 12) {
                Text(isEditing ? "Edit Bookmark" : "Create New Bookmark")
                    .font(.headline)
                
                TextField("Title (optional)", text: $title)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                TextField("URL", text: $urlText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                
                TextField("Tags (comma-separated)", text: $tagText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                HStack {
                    Button(isEditing ? "Update Bookmark" : "Create Bookmark") {
                        createOrUpdateBookmark()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(urlText.isEmpty)
                    
                    if isEditing {
                        Button("Cancel") {
                            cancelEditing()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // CRUD Operations Section
            VStack(spacing: 16) {
                Text("CRUD Operations")
                    .font(.headline)
                
                // Read Operations
                VStack(spacing: 8) {
                    Text("Read Operations")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    
                    HStack(spacing: 12) {
                        Button("Get All") {
                            testGetAll()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Find by URL") {
                            testFindByURL()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Filter by Tag") {
                            testFilterByTag()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                // Bulk Operations
                VStack(spacing: 8) {
                    Text("Bulk Operations")
                        .font(.subheadline)
                        .foregroundColor(.green)
                    
                    HStack(spacing: 12) {
                        Button("Add Sample Data") {
                            addSampleBookmarks()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Replace All") {
                            replaceAllBookmarks()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Delete Selected") {
                            deleteSelectedBookmarks()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                // Danger Zone
                VStack(spacing: 8) {
                    Text("Danger Zone")
                        .font(.subheadline)
                        .foregroundColor(.red)
                    
                    Button("Delete All") {
                        deleteAllBookmarks()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // Current Bookmarks List
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Bookmarks (\(repository.items.count))")
                    .font(.headline)
                
                if repository.items.isEmpty {
                    Text("No bookmarks found")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(repository.items) { bookmark in
                                BookmarkRowView(bookmark: bookmark)
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Bookmark CRUD Test")
        .sheet(isPresented: $showingResults) {
            NavigationView {
                ScrollView {
                    Text(testResults)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                }
                .navigationTitle("Test Results")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingResults = false
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Bookmark Operations
    
    private func createOrUpdateBookmark() {
        guard let url = URL(string: urlText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            showTestResult("Invalid URL: \(urlText)")
            return
        }
        
        let tags = Set(tagText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        let bookmarkTitle = title.isEmpty ? nil : title
        
        let bookmark: Bookmark
        if isEditing, let existing = selectedBookmark {
            bookmark = Bookmark(id: existing.id, title: bookmarkTitle, url: url, tags: tags)
        } else {
            bookmark = Bookmark(id: UUID().uuidString, title: bookmarkTitle, url: url, tags: tags)
        }
        
        repository.save(bookmark)
        
        let action = isEditing ? "Updated" : "Created"
        showTestResult("\(action) bookmark: \(bookmark.title ?? "Untitled") - \(bookmark.url)")
        
        clearForm()
    }
    
    private func editBookmark(_ bookmark: Bookmark) {
        selectedBookmark = bookmark
        title = bookmark.title ?? ""
        urlText = bookmark.url.absoluteString
        tagText = bookmark.tags.joined(separator: ", ")
        isEditing = true
    }
    
    private func deleteBookmark(_ bookmark: Bookmark) {
        repository.delete(bookmark)
        showTestResult("Deleted bookmark: \(bookmark.title ?? "Untitled")")
    }
    
    private func cancelEditing() {
        clearForm()
    }
    
    private func clearForm() {
        title = ""
        urlText = ""
        tagText = ""
        selectedBookmark = nil
        isEditing = false
    }
    
    // MARK: - Test Methods
    
    private func testGetAll() {
        let bookmarks = repository.all()
        showTestResult("all() returned \(bookmarks.count) bookmarks:\n" +
                     bookmarks.map { "• \($0.title ?? "Untitled"): \($0.url)" }.joined(separator: "\n"))
    }
    
    private func testFindByURL() {
        guard !repository.items.isEmpty else {
            showTestResult("No bookmarks to search")
            return
        }
        
        let firstBookmark = repository.items[0]
        let found = repository.find(id: firstBookmark.id)
        showTestResult("find(id:) for '\(firstBookmark.id)':\n" +
                     (found != nil ? "Found: \(found!.title ?? "Untitled")" : "Not found"))
    }
    
    private func testFilterByTag() {
        let bookmarksWithSwift = repository.all { bookmark in
            bookmark.tags.contains("swift") || bookmark.tags.contains("Swift")
        }
        showTestResult("all(where:) for bookmarks with 'swift' tag:\n" +
                     "Found \(bookmarksWithSwift.count) bookmarks:\n" +
                     bookmarksWithSwift.map { "• \($0.title ?? "Untitled")" }.joined(separator: "\n"))
    }
    
    private func addSampleBookmarks() {
        let sampleBookmarks = [
            Bookmark(id: UUID().uuidString, title: "Apple Developer", url: URL(string: "https://developer.apple.com")!, tags: ["swift", "ios", "development"]),
            Bookmark(id: UUID().uuidString, title: "SwiftUI Tutorials", url: URL(string: "https://developer.apple.com/tutorials/swiftui")!, tags: ["swift", "swiftui", "tutorial"]),
            Bookmark(id: UUID().uuidString, title: "GitHub", url: URL(string: "https://github.com")!, tags: ["git", "development", "code"])
        ]
        
        repository.saveMany(upserting: sampleBookmarks)
        showTestResult("saveMany(upserting:) added \(sampleBookmarks.count) sample bookmarks")
    }
    
    private func replaceAllBookmarks() {
        let newBookmarks = [
            Bookmark(id: UUID().uuidString, title: "Swift.org", url: URL(string: "https://swift.org")!, tags: ["swift", "official"]),
            Bookmark(id: UUID().uuidString, title: "Hacking with Swift", url: URL(string: "https://hackingwithswift.com")!, tags: ["swift", "tutorial", "learning"])
        ]
        
        repository.replaceAll(with: newBookmarks)
        showTestResult("replaceAll(with:) replaced all bookmarks with \(newBookmarks.count) new ones")
    }
    
    private func deleteSelectedBookmarks() {
        let bookmarksToDelete = Array(repository.items.prefix(2))
        guard !bookmarksToDelete.isEmpty else {
            showTestResult("No bookmarks to delete")
            return
        }
        
        repository.delete(subset: bookmarksToDelete)
        showTestResult("delete(subset:) removed \(bookmarksToDelete.count) bookmarks")
    }
    
    private func deleteAllBookmarks() {
        let count = repository.items.count
        repository.deleteAll()
        showTestResult("deleteAll() removed all \(count) bookmarks")
    }
    
    private func showTestResult(_ result: String) {
        testResults = result
        showingResults = true
    }
}

#Preview {
    BookmarkCRUDTestView()
}
