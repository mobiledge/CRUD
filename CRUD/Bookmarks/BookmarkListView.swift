import Foundation
import SwiftUI

struct BookmarkListView: View {
    @Binding var searchTokens: [Token]
    @Environment(BookmarkRepository.self) private var repo
    @State private var searchText = ""
    
    private var items: [Bookmark] {
        repo.items
    }
    
    private var filteredItems: [Bookmark] {
        if searchText.isEmpty && searchTokens.isEmpty {
            return items
        } else {
            return items.filter { $0.matches(text: searchText, andTokens: searchTokens) }
        }
    }
    
    var body: some View {
        List(filteredItems) { bookmark in
            BookmarkRowView(bookmark: bookmark)
        }
        .listStyle(.plain)
        .searchable(
            text: $searchText,
            tokens: $searchTokens,
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
        BookmarkListView(searchTokens: .constant([Token]()))
            .environment(BookmarkRepository.mock())
    }
}

// MARK: BookmarkRowView
struct BookmarkRowView: View {
    let bookmark: Bookmark
    
    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            // Favicon Image
            AsyncImage(url: bookmark.faviconURL) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Image(systemName: "globe")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(alignment: .leading) {
                // Title and URL
                if let title = bookmark.title, !title.isEmpty {
                    Text(title)
                        .font(.body)
                    
                    Text(bookmark.url.host ?? "...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text(bookmark.url.absoluteString)
                        .font(.body)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
            }
        }
    }
    
    /// A computed property to create a single, compact string for date information.
    private var dateInfo: String? {
        // Prioritize showing the 'updated' date if it exists
        if let dateModified = bookmark.dateModified {
            return "Updated: \(dateModified.formatted(date: .numeric, time: .omitted))"
        }
        // Fallback to the 'added' date
        if let dateAdded = bookmark.dateAdded {
            return "Added: \(dateAdded.formatted(date: .numeric, time: .omitted))"
        }
        return nil
    }
}
#Preview {
    BookmarkRowView(bookmark: Bookmark.mockValue)
}
