import Foundation
import SwiftUI

struct BookmarkListView: View {
    
    @Environment(BookmarkRepository.self) private var repo
    @State private var searchText = ""
    @State private var currentTokens = [Token]()
    
    private var items: [Bookmark] {
        repo.items
    }
    
    private var filteredItems: [Bookmark] {
        if searchText.isEmpty && currentTokens.isEmpty {
            return items
        } else {
            return items.filter { $0.matches(text: searchText, andTokens: currentTokens) }
        }
    }
    
    var body: some View {
        
        Button("Add Token") {
            let tag = repo.items.randomElement()!.tags.randomElement()!
            let token = Token(name: tag)
            currentTokens.append(token)
        }
        
        Text("Count: \(filteredItems.count)")
        
        List(filteredItems) { bookmark in
            BookmarkRowView(bookmark: bookmark)
        }
//        .searchable(text: $searchText, prompt: "Search bookmarks...")
        .searchable(
            text: $searchText,
            tokens: $currentTokens,
            prompt: Text("Type to filter, or use # for tags")
        ) { token in
            Text(token.name)
        }
        .animation(.default, value: filteredItems.count)
        .navigationTitle("Bookmarks")
    }
}

// MARK: Preview
#Preview {
    NavigationStack {
        BookmarkListView()
            .environment(BookmarkRepository.mock())
    }
}

// MARK: BookmarkRowView
struct BookmarkRowView: View {
    let bookmark: Bookmark
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = bookmark.title, !title.isEmpty {
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
                
                Text(bookmark.url.absoluteString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            } else {
                Text(bookmark.url.absoluteString)
                    .font(.headline)
                    .foregroundColor(.blue)
                    .lineLimit(1)
            }
            
            if !bookmark.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(bookmark.tags.sorted()), id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    BookmarkRowView(bookmark: Bookmark.mockValue)
}
