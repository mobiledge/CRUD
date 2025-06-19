import Foundation

struct Bookmark: Codable, Identifiable  {
    let id: String
    let url: URL
    let tags: Set<String>
}

extension Bookmark: JSONFileCollectionResource {}
