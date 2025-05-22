import Foundation

struct ProductClient {
    
    typealias FetchAllClosure = () async throws -> [Product]
    typealias FetchByIdClosure = (Int) async throws -> Product
    typealias CreateClosure = (Product) async throws -> Product
    typealias UpdateClosure = (Product) async throws -> Product
    typealias DeleteByIdClosure = (Int) async throws -> Void
    
    var fetchAll: FetchAllClosure
    var fetchById: FetchByIdClosure
    var create: CreateClosure
    var update: UpdateClosure
    var delete: DeleteByIdClosure
}

var count = 0

extension ProductClient {
    static func live(client: HTTPClient) -> ProductClient {
        let basePath = "products"
        
        return ProductClient(
            fetchAll: {
                
                count += 1
                if count % 2 == 0 {
                    throw URLError(.unknown)
                }
                let data = try await client.get(basePath)
                let response = try JSONDecoder().decode(ProductListResponse.self, from: data)
                return response.products
            },
            
            fetchById: { id in
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
    
    
    static func mock(
        fetchAll: @escaping FetchAllClosure = { [] },
        fetch: @escaping FetchByIdClosure = { _ in Product.mock },
        create: @escaping CreateClosure = { product in product },
        update: @escaping UpdateClosure = { product in product },
        delete: @escaping DeleteByIdClosure = { _ in }
    ) -> ProductClient {
        return ProductClient(
            fetchAll: fetchAll,
            fetchById: fetch,
            create: create,
            update: update,
            delete: delete
        )
    }
}
