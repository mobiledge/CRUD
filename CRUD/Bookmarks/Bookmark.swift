import Foundation

struct Bookmark: Codable, Identifiable  {
    let id: String
    let title: String?
    let url: URL
    let tags: Set<String>
    
    func matches(searchText: String) -> Bool {
        let titleMatch = title?.localizedCaseInsensitiveContains(searchText) ?? false
        let urlMatch = url.absoluteString.localizedCaseInsensitiveContains(searchText)
        let tagMatch = tags.contains { tag in
            tag.localizedCaseInsensitiveContains(searchText)
        }
        return titleMatch || urlMatch || tagMatch
    }
}

extension Bookmark {
    static var mockValue : Bookmark {
        mockCollection.randomElement()!
    }
    
    static var mockCollection: [Bookmark] {
        try! BundleService.default.get(Bookmark.self).get()
    }
}

extension Bookmark: BundleResourceCollection {}

extension Bookmark: JSONFileCollectionResource {}

typealias BookmarkRepository = JSONFileCollectionResourceRepository<Bookmark>
