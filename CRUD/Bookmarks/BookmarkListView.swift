import Foundation
import SwiftUI

struct BookmarkListView: View {
    @State private var items: [Bookmark] = []
    let repo = JSONFileCollectionResourceRepository<Bookmark>(service: FileService.default)
    var body: some View {
        Text("BookmarkListView: \(items.count)")
        Button("Load & Save") {
            self.items = try! BundleService.default.get(Bookmark.self).get()
        }
    }
}

#Preview {
    BookmarkListView()
}
