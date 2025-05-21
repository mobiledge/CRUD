import Foundation

typealias FetchAllProducts = () async throws -> [Product]
typealias FetchProduct = (Int) async throws -> Product
typealias CreateProduct = (Product) async throws -> Product
typealias UpdateProduct = (Product) async throws -> Product
typealias DeleteProduct = (Int) async throws -> Void

struct ProductClient {
    var fetchAll: FetchAllProducts
    var fetch: FetchProduct
    var create: CreateProduct
    var update: UpdateProduct
    var delete: DeleteProduct
}

extension ProductClient {
    static func live(client: Client) -> ProductClient {
        let basePath = "products"
        
        return ProductClient(
            fetchAll: {
                let data = try await client.get(basePath)
                let decoded = try JSONDecoder().decode([Product].self, from: data)
                return decoded
            },
            
            fetch: { id in
                let data = try await client.get("\(basePath)/\(id)")
                return try JSONDecoder().decode(Product.self, from: data)
            },
            
            create: { product in
                let body = try JSONEncoder().encode(product)
                let data = try await client.post(basePath, body: body)
                return try JSONDecoder().decode(Product.self, from: data)
            },
            
            update: { product in
                let body = try JSONEncoder().encode(product)
                let data = try await client.put("\(basePath)/\(product.id)", body: body)
                return try JSONDecoder().decode(Product.self, from: data)
            },
            
            delete: { id in
                _ = try await client.delete("\(basePath)/\(id)")
            }
        )
    }
    
    // **MARK: - Mock Implementation**
    static func mock() -> ProductClient {
        var products = Product.mockProducts
        
        return ProductClient(
            fetchAll: {
                return products
            },
            
            fetch: { id in
                if let product = products.first(where: { $0.id == id }) {
                    return product
                }
                throw NSError(domain: "ProductClient", code: 404, userInfo: [NSLocalizedDescriptionKey: "Product not found"])
            },
            
            create: { product in
                // Ensure no duplicate IDs
                guard !products.contains(where: { $0.id == product.id }) else {
                    throw NSError(domain: "ProductClient", code: 409, userInfo: [NSLocalizedDescriptionKey: "Product with this ID already exists"])
                }
                products.append(product)
                return product
            },
            
            update: { product in
                if let index = products.firstIndex(where: { $0.id == product.id }) {
                    products[index] = product
                    return product
                }
                throw NSError(domain: "ProductClient", code: 404, userInfo: [NSLocalizedDescriptionKey: "Product not found"])
            },
            
            delete: { id in
                products.removeAll(where: { $0.id == id })
            }
        )
    }
    
    // **MARK: - Preview Implementation**
    static var preview: ProductClient {
        return ProductClient(
            fetchAll: {
                return Product.mockProducts
            },
            
            fetch: { id in
                if let product = Product.mockProducts.first(where: { $0.id == id }) {
                    return product
                }
                return Product.mock
            },
            
            create: { product in
                // Preview implementation just returns the product without creating
                return product
            },
            
            update: { product in
                // Preview implementation just returns the product without updating
                return product
            },
            
            delete: { _ in
                // Preview implementation does nothing for delete
            }
        )
    }
}
