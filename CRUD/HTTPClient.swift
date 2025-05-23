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

    init(
        url: URL,
        method: HTTPMethod = .get,
        headers: [String: String]? = nil,
        body: HTTPBody? = nil
    ) {
        self.init(url: url)
        self.httpMethod = method.rawValue
        self.httpBody = body
        headers?.forEach { self.setValue($1, forHTTPHeaderField: $0) }
    }

    static func get(
        server: HTTPServer,
        path: HTTPPath,
        headers: [String: String]? = nil
    ) -> URLRequest {
        URLRequest(server: server, path: path, method: .get, headers: headers)
    }

    static func post(
        server: HTTPServer,
        path: HTTPPath,
        headers: [String: String]? = nil,
        body: HTTPBody
    ) -> URLRequest {
        URLRequest(server: server, path: path, method: .post, headers: headers, body: body)
    }

    static func put(
        server: HTTPServer,
        path: HTTPPath,
        headers: [String: String]? = nil,
        body: HTTPBody
    ) -> URLRequest {
        URLRequest(server: server, path: path, method: .put, headers: headers, body: body)
    }

    static func delete(
        server: HTTPServer,
        path: HTTPPath,
        headers: [String: String]? = nil,
        body: HTTPBody? = nil
    ) -> URLRequest {
        URLRequest(server: server, path: path, method: .delete, headers: headers, body: body)
    }
}

// MARK: - ProductClient

struct ProductClient {
    let fetchAll: () async throws -> [Product]
    let fetchById: (_ id: Int) async throws -> Product
    let create: (_ product: Product) async throws -> Product
    let update: (_ product: Product) async throws -> Product
    let delete: (_ id: Int) async throws -> Void

    static func live(server: HTTPServer, session: HTTPSession) -> ProductClient {
        let liveClient = LiveProductClient(server: server, session: session)
        return ProductClient(
            fetchAll: liveClient.fetchAll,
            fetchById: liveClient.fetchById,
            create: liveClient.create,
            update: liveClient.update,
            delete: liveClient.delete
        )
    }

    static func mock(
        fetchAll: @escaping () async throws -> [Product] = { [Product.mock] },
        fetchById: @escaping (Int) async throws -> Product = { _ in Product.mock },
        create: @escaping (Product) async throws -> Product = { $0 },
        update: @escaping (Product) async throws -> Product = { $0 },
        delete: @escaping (Int) async throws -> Void = { _ in }
    ) -> ProductClient {
        ProductClient(
            fetchAll: fetchAll,
            fetchById: fetchById,
            create: create,
            update: update,
            delete: delete
        )
    }
}

private struct LiveProductClient {
    let server: HTTPServer
    let session: HTTPSession

    func fetchAll() async throws -> [Product] {
        let request = URLRequest.get(server: server, path: "products")
        let data = try await session.dispatch(request: request)
        let decoded = try JSONDecoder().decode(ProductListResponse.self, from: data)
        return decoded.products
    }

    func fetchById(_ id: Int) async throws -> Product {
        let request = URLRequest.get(server: server, path: "products/\(id)")
        let data = try await session.dispatch(request: request)
        return try JSONDecoder().decode(Product.self, from: data)
    }

    func create(_ product: Product) async throws -> Product {
        let body = try JSONEncoder().encode(product)
        let request = URLRequest.post(
            server: server,
            path: "products/add",
            headers: ["Content-Type": "application/json"],
            body: body
        )
        let data = try await session.dispatch(request: request)
        return try JSONDecoder().decode(Product.self, from: data)
    }

    func update(_ product: Product) async throws -> Product {
        let body = try JSONEncoder().encode(product)
        let request = URLRequest.put(
            server: server,
            path: "products/\(product.id)",
            headers: ["Content-Type": "application/json"],
            body: body
        )
        let data = try await session.dispatch(request: request)
        return try JSONDecoder().decode(Product.self, from: data)
    }

    func delete(_ id: Int) async throws {
        let request = URLRequest.delete(server: server, path: "products/\(id)")
        _ = try await session.dispatch(request: request)
    }
}


struct FetchAllProductsService {
    let fetchAll: () async throws -> [Product]
    
    static func live(server: HTTPServer, session: HTTPSession) -> FetchAllProductsService {
        .init {
            let request = URLRequest.get(server: server, path: "products")
            let data = try await session.dispatch(request: request)
            let decoded = try JSONDecoder().decode(ProductListResponse.self, from: data)
            return decoded.products
        }
    }
    
    static func mock(fetchAll: @escaping () async throws -> [Product]) -> FetchAllProductsService {
        FetchAllProductsService(fetchAll: fetchAll)
    }
}

struct FetchProductByIdService {
    let fetchById: (_ id: Int) async throws -> Product

    static func live(server: HTTPServer, session: HTTPSession) -> FetchProductByIdService {
        .init { id in
            let request = URLRequest.get(server: server, path: "products/\(id)")
            let data = try await session.dispatch(request: request)
            return try JSONDecoder().decode(Product.self, from: data)
        }
    }

    static func mock(fetchById: @escaping (Int) async throws -> Product) -> FetchProductByIdService {
        FetchProductByIdService(fetchById: fetchById)
    }
}

struct CreateProductService {
    let create: (_ product: Product) async throws -> Product

    static func live(server: HTTPServer, session: HTTPSession) -> CreateProductService {
        .init { product in
            let body = try JSONEncoder().encode(product)
            let request = URLRequest.post(
                server: server,
                path: "products/add",
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
}

struct UpdateProductService {
    let update: (_ product: Product) async throws -> Product

    static func live(server: HTTPServer, session: HTTPSession) -> UpdateProductService {
        .init { product in
            let body = try JSONEncoder().encode(product)
            let request = URLRequest.put(
                server: server,
                path: "products/\(product.id)",
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
}

struct DeleteProductService {
    let delete: (_ id: Int) async throws -> Void

    static func live(server: HTTPServer, session: HTTPSession) -> DeleteProductService {
        .init { id in
            let request = URLRequest.delete(server: server, path: "products/\(id)")
            _ = try await session.dispatch(request: request)
        }
    }

    static func mock(delete: @escaping (Int) async throws -> Void) -> DeleteProductService {
        DeleteProductService(delete: delete)
    }
}
