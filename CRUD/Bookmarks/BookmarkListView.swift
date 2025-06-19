import Foundation
import SwiftUI

struct BookmarkListView: View {
    
    @Environment(BookmarkRepository.self) private var repo
    @State private var searchText = ""
    
    private var items: [Bookmark] {
        repo.items
    }
    
    private var filteredItems: [Bookmark] {
        if searchText.isEmpty {
            return items
        } else {
            return items.filter { bookmark in
                // Search in title, URL, and tags
                let titleMatch = bookmark.title?.localizedCaseInsensitiveContains(searchText) ?? false
                let urlMatch = bookmark.url.absoluteString.localizedCaseInsensitiveContains(searchText)
                let tagMatch = bookmark.tags.contains { tag in
                    tag.localizedCaseInsensitiveContains(searchText)
                }
                
                return titleMatch || urlMatch || tagMatch
            }
        }
    }
    
    var body: some View {
        List(filteredItems) { bookmark in
            BookmarkRowView(bookmark: bookmark)
        }
        .searchable(text: $searchText, prompt: "Search bookmarks...")
        .animation(.default, value: filteredItems.count)
        .navigationTitle("Bookmarks")
    }
}

// MARK: Preview
#Preview {
    NavigationStack {
        BookmarkListView()
            .environment(BookmarkRepository())
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
