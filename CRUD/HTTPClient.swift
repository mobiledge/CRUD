import Foundation

// MARK: - Typealiases

typealias HTTPPath = String
typealias HTTPBody = Data

// MARK: - HTTPMethod

enum HTTPMethod: String {
    case get = "GET", post = "POST", put = "PUT", delete = "DELETE"
}

// MARK: - HTTPServer

struct HTTPServer {
    let url: URL
    let description: String?

    init(url: URL, description: String? = nil) {
        self.url = url
        self.description = description
    }

    init(staticString: StaticString, description: String? = nil) {
        guard let url = URL(string: "\(staticString)") else {
            preconditionFailure("Invalid static URL: \(staticString)")
        }
        self.init(url: url, description: description)
    }

    static let prod = HTTPServer(staticString: "https://dummyjson.com/", description: "Production")
    static let local = HTTPServer(staticString: "http://localhost:3000/", description: "Production")
    static let mock = HTTPServer(staticString: "https://mock.api/", description: "Mock")
}

// MARK: - HTTPSession

struct HTTPSession {
    private var dispatchRequest: (URLRequest) async throws -> Data
    
    func dispatch(request: URLRequest) async throws -> Data {
        try await dispatchRequest(request)
    }

    static func live(session: URLSession = .shared) -> HTTPSession {
        HTTPSession { request in
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw HTTPError.badHTTPResponse
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw HTTPError.badStatusCode(httpResponse.statusCode)
            }
            return data
        }
    }
}

// MARK: - HTTPError

enum HTTPError: Error {
    case badHTTPResponse
    case badStatusCode(Int)
}

// MARK: - ProductsService
struct FetchAllProductsService {
    let fetchAll: () async throws -> [Product]

    static func live(server: HTTPServer, session: HTTPSession) -> FetchAllProductsService {
        .init {
            let request = URLRequest(server: server, path: "products", method: .get)
            let data = try await session.dispatch(request: request)
            return try JSONDecoder().decode([Product].self, from: data)
        }
    }

    static func mock(fetchAll: @escaping () async throws -> [Product]) -> FetchAllProductsService {
        FetchAllProductsService(fetchAll: fetchAll)
    }

    static var mockHappyPath: FetchAllProductsService {
        .mock {
            return Product.mockProducts
        }
    }

    static func mockError(_ error: Error) -> FetchAllProductsService {
        .mock {
            throw error
        }
    }
}

struct FetchProductByIdService {
    let fetchById: (_ id: Int) async throws -> Product

    static func live(server: HTTPServer, session: HTTPSession) -> FetchProductByIdService {
        .init { id in
            let request = URLRequest(server: server, path: "products/\(id)", method: .get)
            let data = try await session.dispatch(request: request)
            return try JSONDecoder().decode(Product.self, from: data)
        }
    }

    static func mock(fetchById: @escaping (Int) async throws -> Product) -> FetchProductByIdService {
        FetchProductByIdService(fetchById: fetchById)
    }

    static var mockHappyPath: FetchProductByIdService {
        .mock { id in
            guard let product = Product.mockProducts.first(where: { $0.id == id }) else {
                throw NSError(domain: "NotFound", code: 404, userInfo: nil)
            }
            return product
        }
    }

    static func mockError(_ error: Error) -> FetchProductByIdService {
        .mock { _ in
            throw error
        }
    }
}

struct CreateProductService {
    let create: (_ product: Product) async throws -> Product

    static func live(server: HTTPServer, session: HTTPSession) -> CreateProductService {
        .init { product in
            let body = try JSONEncoder().encode(product)
            let request = URLRequest(
                server: server,
                path: "products/add",
                method: .post,
                headers: ["Content-Type": "application/json"],
                body: body
            )
            let data = try await session.dispatch(request: request)
            return try JSONDecoder().decode(Product.self, from: data)
        }
    }

    static func mock(create: @escaping (Product) async throws -> Product) -> CreateProductService {
        CreateProductService(create: create)
    }

    static var mockHappyPath: CreateProductService {
        .mock { product in
            return product
        }
    }

    static func mockError(_ error: Error) -> CreateProductService {
        .mock { _ in
            throw error
        }
    }
}

struct UpdateProductService {
    let update: (_ product: Product) async throws -> Product

    static func live(server: HTTPServer, session: HTTPSession) -> UpdateProductService {
        .init { product in
            let body = try JSONEncoder().encode(product)
            let request = URLRequest(
                server: server,
                path: "products/\(product.id)",
                method: .put,
                headers: ["Content-Type": "application/json"],
                body: body
            )
            let data = try await session.dispatch(request: request)
            return try JSONDecoder().decode(Product.self, from: data)
        }
    }

    static func mock(update: @escaping (Product) async throws -> Product) -> UpdateProductService {
        UpdateProductService(update: update)
    }

    static var mockHappyPath: UpdateProductService {
        .mock { product in
            return product
        }
    }

    static func mockError(_ error: Error) -> UpdateProductService {
        .mock { _ in
            throw error
        }
    }
}

struct DeleteProductService {
    let delete: (_ id: Int) async throws -> Void

    static func live(server: HTTPServer, session: HTTPSession) -> DeleteProductService {
        .init { id in
            let request = URLRequest(server: server, path: "products/\(id)", method: .delete)
            _ = try await session.dispatch(request: request)
        }
    }

    static func mock(delete: @escaping (Int) async throws -> Void) -> DeleteProductService {
        DeleteProductService(delete: delete)
    }

    static var mockHappyPath: DeleteProductService {
        .mock { _ in
            // simulate successful deletion
        }
    }

    static func mockError(_ error: Error) -> DeleteProductService {
        .mock { _ in
            throw error
        }
    }
}

// MARK: - URLRequest Extensions

extension URLRequest {
    init(
        server: HTTPServer,
        path: HTTPPath,
        method: HTTPMethod = .get,
        headers: [String: String]? = nil,
        body: HTTPBody? = nil
    ) {
        let fullURL = server.url.appending(path: path)
        self.init(url: fullURL)
        self.httpMethod = method.rawValue
        self.httpBody = body
        headers?.forEach { self.setValue($1, forHTTPHeaderField: $0) }
    }
}


// MARK: - ProductService

struct ProductService {
    let fetchAll: () async throws -> [Product]
    let fetchById: (_ id: Int) async throws -> Product
    let create: (_ product: Product) async throws -> Product
    let update: (_ product: Product) async throws -> Product
    let delete: (_ id: Int) async throws -> Void

    static func live(server: HTTPServer, session: HTTPSession) -> ProductService {
        ProductService(
            fetchAll: {
                let request = URLRequest(server: server, path: "products", method: .get)
                let data = try await session.dispatch(request: request)
                return try JSONDecoder().decode([Product].self, from: data)
            },
            fetchById: { id in
                let request = URLRequest(server: server, path: "products/\(id)", method: .get)
                let data = try await session.dispatch(request: request)
                return try JSONDecoder().decode(Product.self, from: data)
            },
            create: { product in
                let body = try JSONEncoder().encode(product)
                let request = URLRequest(
                    server: server,
                    path: "products/add",
                    method: .post,
                    headers: ["Content-Type": "application/json"],
                    body: body
                )
                let data = try await session.dispatch(request: request)
                return try JSONDecoder().decode(Product.self, from: data)
            },
            update: { product in
                let body = try JSONEncoder().encode(product)
                let request = URLRequest(
                    server: server,
                    path: "products/\(product.id)",
                    method: .put,
                    headers: ["Content-Type": "application/json"],
                    body: body
                )
                let data = try await session.dispatch(request: request)
                return try JSONDecoder().decode(Product.self, from: data)
            },
            delete: { id in
                let request = URLRequest(server: server, path: "products/\(id)", method: .delete)
                _ = try await session.dispatch(request: request)
            }
        )
    }

    static func mock(
        fetchAll: @escaping () async throws -> [Product] = { Product.mockProducts },
        fetchById: @escaping (Int) async throws -> Product = { id in
            guard let product = Product.mockProducts.first(where: { $0.id == id }) else {
                throw NSError(domain: "NotFound", code: 404)
            }
            return product
        },
        create: @escaping (Product) async throws -> Product = { $0 },
        update: @escaping (Product) async throws -> Product = { $0 },
        delete: @escaping (Int) async throws -> Void = { _ in }
    ) -> ProductService {
        ProductService(
            fetchAll: fetchAll,
            fetchById: fetchById,
            create: create,
            update: update,
            delete: delete
        )
    }

    static func mockError(_ error: Error) -> ProductService {
        mock(
            fetchAll: { throw error },
            fetchById: { _ in throw error },
            create: { _ in throw error },
            update: { _ in throw error },
            delete: { _ in throw error }
        )
    }
}
