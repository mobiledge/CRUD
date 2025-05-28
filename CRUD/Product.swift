import Foundation

struct Product: Codable, Identifiable {
    let id: Int
    var name: String
    var description: String?
    var price: String?
}

extension Product {
    static let mockArray: [Product] = [
        Product(
            id: 1,
            name: "Bluetooth Headphones",
            description: "Wireless over-ear headphones with noise cancellation.",
            price: "$89.99"
        ),
        Product(
            id: 2,
            name: "Eco Water Bottle",
            description: "Reusable stainless steel water bottle, 1L.",
            price: "$19.95"
        ),
        Product(
            id: 3,
            name: "Smart LED Bulb",
            description: "Color-changing bulb with remote and app control.",
            price: "$14.50"
        ),
        Product(
            id: 4,
            name: "Notebook Set",
            description: "Set of 3 dotted notebooks for journaling.",
            price: "$11.25"
        ),
        Product(
            id: 5,
            name: "Portable Charger",
            description: "10000mAh power bank with fast charging support.",
            price: "$24.99"
        ),
        Product(
            id: 6,
            name: "Minimalist Wallet",
            description: "Slim RFID-blocking wallet with room for 10 cards.",
            price: "$29.90"
        ),
        Product(
            id: 7,
            name: "Standing Desk",
            description: "Adjustable height desk for home or office use.",
            price: "$199.00"
        ),
        Product(
            id: 8,
            name: "Yoga Mat",
            description: "Non-slip, extra thick yoga mat (6mm).",
            price: "$32.80"
        ),
        Product(
            id: 9,
            name: "USB-C Hub",
            description: "7-in-1 USB-C hub with HDMI and card reader.",
            price: "$39.99"
        ),
        Product(
            id: 10,
            name: "Coffee Grinder",
            description: "Manual burr grinder for fresh coffee beans.",
            price: "$45.00"
        )
    ]
    
    static let mockValue = Product(
        id: 1,
        name: "Bluetooth Headphones",
        description: "Wireless over-ear headphones with noise cancellation.",
        price: "$89.99"
    )
}

extension Product: CustomDebugStringConvertible {
    var debugDescription: String {
        return "Product(id: \(id), name: \"\(name)\")"
    }
}

extension Product {
    
    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    init(jsonData: Data) throws {
        self = try Product.decoder.decode(Product.self, from: jsonData)
    }

    func toJSONData() throws -> Data {
        return try Product.encoder.encode(self)
    }

    static func array(from jsonData: Data) throws -> [Product] {
        return try Product.decoder.decode([Product].self, from: jsonData)
    }

    static func toJSONData(from instances: [Product]) throws -> Data {
        return try Product.encoder.encode(instances)
    }
}
