import Foundation

// MARK: - Product Model
struct Product: Codable, Identifiable, Equatable {
    let id: Int
    var title: String
    
    static let mockProducts: [Product] = [
        Product(id: 1, title: "iPhone"),
        Product(id: 2, title: "MacBook"),
        Product(id: 3, title: "Headphones"),
        Product(id: 4, title: "Coffee Maker")
    ]
    
    static let mock = Product(id: 1, title: "iPhone")
}

private struct ProductListResponse: Decodable {
    let products: [Product]
}
