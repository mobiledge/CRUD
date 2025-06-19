import Foundation
import SwiftUI

struct BookmarkListView: View {
    private var items: [Bookmark] {
        repo.items
    }
    let repo = JSONFileCollectionResourceRepository<Bookmark>(service: FileService.default)
    var body: some View {
        Text("BundleService: \(items.count)")
        Button("Load & Save", action: loadInitial)
        Button("Remove All", action: removeAll)
        List(items) { item in
            Text(item.url.absoluteString)
        }
    }
    
    func loadInitial() {
        let arr = try! BundleService.default.get(Bookmark.self).get()
        repo.saveMany(upserting: arr)
    }
    
    func removeAll() {
        repo.deleteAll()
    }
}

#Preview {
    BookmarkListView()
}
