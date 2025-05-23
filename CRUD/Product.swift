import Foundation

struct Product: Codable, Identifiable {
    let id: Int
    let name: String

    // Mock data for testing and previews
    static let mockProducts: [Product] = [
        Product(id: 1, name: "Awesome T-Shirt"),
        Product(id: 2, name: "Stylish Mug"),
        Product(id: 3, name: "Coding Book"),
        Product(id: 4, name: "Wireless Headphones")
    ]

    // Single mock product
    static let mock = Product(id: 99, name: "Test Product")
}
