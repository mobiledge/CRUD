import Foundation

struct ProductClient {
    let fetchAll: () async throws -> [Product]
    let fetchById: (_ id: Int) async throws -> Product
    let create: (_ product: Product) async throws -> Product
    let update: (_ product: Product) async throws -> Product
    let delete: (_ id: Int) async throws -> Void
}

extension ProductClient {
    static func live(server: HTTPServer, session: HTTPSession) -> ProductClient {
        ProductClient(
            fetchAll: {
                let req = URLRequest.get(server: server, path: "products")
                let data = try await session.dispatch(request: req)
                let response = try JSONDecoder().decode(ProductListResponse.self, from: data)
                return response.products
            },
            fetchById: { id in
                let req = URLRequest.get(server: server, path: "products/\(id)")
                let data = try await session.dispatch(request: req)
                return try JSONDecoder().decode(Product.self, from: data)
            },
            create: { product in
                let body = try JSONEncoder().encode(product)
                let req = URLRequest.post(server: server, path: "products/add", headers: ["Content-Type": "application/json"], body: body)
                let data = try await session.dispatch(request: req)
                return try JSONDecoder().decode(Product.self, from: data)
            },
            update: { product in
                let body = try JSONEncoder().encode(product)
                let req = URLRequest.put(server: server, path: "products/\(product.id)", headers: ["Content-Type": "application/json"], body: body)
                let data = try await session.dispatch(request: req)
                return try JSONDecoder().decode(Product.self, from: data)
            },
            delete: { id in
                let req = URLRequest.delete(server: server, path: "products/\(id)")
                _ = try await session.dispatch(request: req)
            }
        )
    }
}

extension ProductClient {
    static func mock(
        fetchAll: @escaping () async throws -> [Product] = { [Product.mock] },
        fetchById: @escaping (Int) async throws -> Product = { _ in Product.mock },
        create: @escaping (Product) async throws -> Product = { product in product },
        update: @escaping (Product) async throws -> Product = { product in product },
        delete: @escaping (Int) async throws -> Void = { _ in }
    ) -> ProductClient {
        return ProductClient(
            fetchAll: fetchAll,
            fetchById: fetchById,
            create: create,
            update: update,
            delete: delete
        )
    }
}
