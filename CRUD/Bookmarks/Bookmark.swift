import Foundation

struct Bookmark: Codable, Identifiable  {
    let id: String
    let title: String?
    let url: URL
    let dateAdded: Date?
    let dateModified: Date?
    let faviconURL: URL?
    let tags: Set<String>
    
    func matches(text: String) -> Bool {
        if text.isEmpty {
            return true
        }
        let titleMatch = title?.localizedCaseInsensitiveContains(text) ?? false
        let urlMatch = url.absoluteString.localizedCaseInsensitiveContains(text)
        let tagMatch = tags.contains { tag in
            tag.localizedCaseInsensitiveContains(text)
        }
        return titleMatch || urlMatch || tagMatch
    }
    
    func matches(tokens: [Token]) -> Bool {
        if tokens.isEmpty {
            return true
        }
        return tokens.allSatisfy { token in
            tags.contains { tag in
                tag.localizedCaseInsensitiveContains(token.name)
            }
        }
    }
    
    func matches(text: String, andTokens tokens: [Token]) -> Bool {
        // Must match the text AND all tokens
        let matches = matches(text: text) && matches(tokens: tokens)
        return matches
    }
    
    static let encoder = {
        let en = JSONEncoder()
        en.dateEncodingStrategy = .iso8601
        return en
    }()
    
    static let decoder = {
        let de = JSONDecoder()
        de.dateDecodingStrategy = .iso8601
        return de
    }()
}

struct Token: Identifiable {
    var id: String { name }
    var name: String
}

extension Bookmark {
    static var mockValue : Bookmark {
        mockCollection.randomElement()!
    }
    
    static var mockCollection: [Bookmark] {
        try! BundleService.default.get(Bookmark.self).get()
    }
}

extension Bookmark: BundleResourceCollection, JSONFileCollectionResource {
    static func encode(items: [Bookmark]) -> Result<Data, Error> {
        Result {
            try Bookmark.encoder.encode(items)
        }
    }
    static func decode(from data: Data) -> Result<[Bookmark], Error> {
        Result {
            try Bookmark.decoder.decode([Bookmark].self, from: data)
        }
    }
}

typealias BookmarkRepository = JSONFileCollectionResourceRepository<Bookmark>

extension BookmarkRepository {
    static func mock() -> BookmarkRepository {
        let repo = BookmarkRepository()
        repo.saveMany(upserting: Bookmark.mockCollection)
        return repo
    }
    
    var tags: [String] {
        let set = Set(items.flatMap { $0.tags })
        var arr = Array(set)
        arr.sort()
        return arr
    }
}
