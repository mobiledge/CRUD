import Foundation
import SwiftUI

struct BookmarkListView: View {
    
    @State private var itemsRemoved = [Bookmark]()
    
    @Environment(BookmarkRepository.self) private var repo
    
    private var items: [Bookmark] {
        repo.items
    }
    
    
    var body: some View {
        List(items) { bookmark in
            BookmarkRowView(bookmark: bookmark)
        }
        .animation(.default, value: items.count)
    }
    
    func loadInitial() {
        let arr = try! BundleService.default.get(Bookmark.self).get()
        repo.saveMany(upserting: arr)
    }
    
    func removeAll() {
        repo.deleteAll()
    }
    
    func removeFirst() {
        let first = items.first!
        itemsRemoved.append(first)
        repo.delete(first)
    }
    
    func insertOne() {
        if let first = itemsRemoved.first {
            itemsRemoved.remove(at: 0)
            repo.save(first)
        }
    }
    
    func insertAll() {
        repo.saveMany(upserting: itemsRemoved)
        itemsRemoved.removeAll()
    }
}

// MARK: Preview
#Preview {
    BookmarkListView()
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
