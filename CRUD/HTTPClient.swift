import Foundation
import os.log

// https://davedelong.com/blog/2020/06/27/http-in-swift-part-1/
// https://github.com/davedelong/extendedswift/tree/main/Sources/HTTP

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
    static let local = HTTPServer(staticString: "http://localhost:3000/", description: "Local Development")
    static let mock = HTTPServer(staticString: "https://mock.api/", description: "Mock")
}

// MARK: - HTTPSession

struct HTTPSession {
    var dispatch: (URLRequest) async throws -> (Data, URLResponse)

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "HTTPSession", category: "networking")

    static func live(session: URLSession = .shared) -> HTTPSession {
        HTTPSession { request in
            do {
                logger.info("Making HTTP request to: \(request.url?.absoluteString ?? "unknown URL")")
                let (data, response) = try await session.data(for: request)
                logger.info("HTTP request successful, received \(data.count) bytes")
                return (data, response)

            } catch {
                logger.error("HTTP request failed with error: \(error.localizedDescription)")
                throw error
            }
        }
    }

    static func mockError(_ error: Error) -> HTTPSession {
        HTTPSession { _ in
            throw error
        }
    }

    static func mockSuccess(data: Data, urlResponse: URLResponse) -> HTTPSession {
        HTTPSession { _ in
            return (data, urlResponse)
        }
    }
}

// MARK: - HTTPRequest

struct HTTPRequest {
    /// If server is not set, `NetworkService` is responsible for assigning a default server during dispatch.
    var server: HTTPServer? = nil
    var urlComponents = URLComponents()
    var method: HTTPMethod = .get
    var headers: [String: String] = [:]
    var body: Data?

    // MARK: - Fluent Interface

    func server(_ server: HTTPServer) -> Self {
        var copy = self
        copy.server = server
        return copy
    }

    func path(_ path: String) -> Self {
        var copy = self
        copy.urlComponents.path = path
        return copy
    }

    func queryItems(_ items: [URLQueryItem]) -> Self {
        var copy = self
        copy.urlComponents.queryItems = items
        return copy
    }

    func method(_ method: HTTPMethod) -> Self {
        var copy = self
        copy.method = method
        return copy
    }

    func header(key: String, value: String) -> Self {
        var copy = self
        copy.headers[key] = value
        return copy
    }

    func headers(_ headers: [String: String]) -> Self {
        var copy = self
        for (key, value) in headers {
            copy.headers[key] = value
        }
        return copy
    }

    func body(_ body: Data?) -> Self {
        var copy = self
        copy.body = body
        return copy
    }

    // MARK: - Static Helper Methods

    static func get(path: String) -> HTTPRequest {
        HTTPRequest()
            .method(.get)
            .path(path)
    }

    static func post(path: String, body: Data?) -> HTTPRequest {
        HTTPRequest()
            .method(.post)
            .path(path)
            .body(body)
    }

    static func put(path: String, body: Data?) -> HTTPRequest {
        HTTPRequest()
            .method(.put)
            .path(path)
            .body(body)
    }

    static func delete(path: String) -> HTTPRequest {
        HTTPRequest()
            .method(.delete)
            .path(path)
    }

    // MARK: - URLRequest Generation

    func generateURLRequest() throws -> URLRequest {
        guard let server = server else {
            throw HTTPError.badRequest(reason: "Server not set for the request.")
        }

        guard var components = URLComponents(url: server.url, resolvingAgainstBaseURL: true) else {
            throw HTTPError.invalidServerURL
        }

        components.path += urlComponents.path
        if let queryItems = urlComponents.queryItems {
            components.queryItems = (components.queryItems ?? []) + queryItems
        }

        guard let finalURL = components.url else {
            throw HTTPError.badRequest(reason: "Failed to construct the final URL.")
        }

        var urlRequest = URLRequest(url: finalURL)
        urlRequest.httpMethod = method.rawValue
        urlRequest.httpBody = body
        urlRequest.allHTTPHeaderFields = headers

        return urlRequest
    }
}

// MARK: - HTTPResponse

struct HTTPResponse {
    let data: Data
    let response: URLResponse
}


// MARK: - HTTPError

enum HTTPError: Error, Equatable { // Equatable for easier testing
    case invalidServerURL
    case badRequest(reason: String)
    case badHTTPResponse
    case badStatusCode(Int)
}

// MARK: - Middleware Definitions
struct NetworkRequestMiddleware {
    var configureRequest: (inout HTTPRequest) throws -> Void
}

extension NetworkRequestMiddleware {
    static func logRequest() -> NetworkRequestMiddleware {
        NetworkRequestMiddleware { request in
            print("\n--- Network Request ---")
            print("Server: \(request.server?.url.absoluteString ?? "N/A")")
            print("Path: \(request.urlComponents.path)")
            print("Method: \(request.method.rawValue)")
            print("Headers: \(request.headers)")
            if let data = request.body, let dataString = String(data: data, encoding: .utf8) {
                print("Body: \(dataString)")
            }
            print("---------------------\n")
        }
    }

    static func logRequestCompact() -> NetworkRequestMiddleware {
        NetworkRequestMiddleware { request in
            let serverURL = request.server?.url.absoluteString ?? ""
            let fullPath = "\(serverURL)\(request.urlComponents.path)"
            print("➡️ \(request.method.rawValue) \(fullPath)")
        }
    }

    static func jsonHeaders() -> NetworkRequestMiddleware {
        NetworkRequestMiddleware { request in
            request.headers["Content-Type"] = "application/json"
            request.headers["Accept"] = "application/json"
        }
    }
}

struct NetworkResponseMiddleware {
    var processResponse: (inout HTTPResponse) throws -> Void
}

extension NetworkResponseMiddleware {
    static func validateHTTPStatusCode() -> NetworkResponseMiddleware {
        NetworkResponseMiddleware { result in
            guard let httpResponse = result.response as? HTTPURLResponse else {
                throw HTTPError.badHTTPResponse
            }
            let validRange: ClosedRange<Int> = 200...299
            guard validRange.contains(httpResponse.statusCode) else {
                throw HTTPError.badStatusCode(httpResponse.statusCode)
            }
        }
    }

    static func logResponse() -> NetworkResponseMiddleware {
        NetworkResponseMiddleware { result in
            if let httpResponse = result.response as? HTTPURLResponse {
                print("\n--- Network Response ---")
                print("URL: \(httpResponse.url?.absoluteString ?? "N/A")")
                print("Status Code: \(httpResponse.statusCode)")
                print("Headers: \(httpResponse.allHeaderFields)")
                if let dataString = String(data: result.data, encoding: .utf8) {
                    print("Body: \(dataString)")
                }
                print("----------------------\n")
            }
        }
    }
    
    static func logResponseCompact() -> NetworkResponseMiddleware {
        NetworkResponseMiddleware { result in
            if let response = result.response as? HTTPURLResponse {
                print("⬅️ \(response.statusCode) \(response.url?.absoluteString ?? "N/A")")
            }
        }
    }
}

// MARK: - NetworkService
actor NetworkService {
    private let server: HTTPServer
    private let session: HTTPSession
    private let requestMiddlewares: [NetworkRequestMiddleware]
    private let responseMiddlewares: [NetworkResponseMiddleware]


    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "NetworkService", category: "networking")

    init(
        server: HTTPServer,
        session: HTTPSession,
        requestMiddlewares: [NetworkRequestMiddleware] = [],
        responseMiddlewares: [NetworkResponseMiddleware] = []
    ) {
        self.server = server
        self.session = session
        self.requestMiddlewares = requestMiddlewares
        self.responseMiddlewares = responseMiddlewares
    }
    
    func dispatch(request: HTTPRequest) async throws -> HTTPResponse {

        var req = request
        if req.server == nil {
            req.server = server
        }

        // 1. Apply request middlewares to the HTTPRequest
        for middleware in requestMiddlewares {
            try middleware.configureRequest(&req)
        }
        
        // 2. Generate the URLRequest from the (potentially modified) HTTPRequest
        let urlRequest = try req.generateURLRequest()
        
        // 3. Dispatch the URLRequest and get raw data and response
        let (data, urlResponse) = try await session.dispatch(urlRequest)

        // 4. Create an HTTPResponse object
        var result = HTTPResponse(data: data, response: urlResponse)
        
        // 5. Apply response middlewares to the HTTPResponse
        for middleware in responseMiddlewares {
            try middleware.processResponse(&result)
        }

        // 6. Return the final, processed HTTPResponse
        return result
    }
}

extension NetworkService {
    static func live(server: HTTPServer) -> NetworkService {
        NetworkService(
            server: server,
            session: .live(),
            requestMiddlewares: [
                .jsonHeaders(),
                .logRequestCompact()
            ],
            responseMiddlewares: [
                .logResponseCompact(),
                .validateHTTPStatusCode()
            ]
        )
    }
    static func mockSuccess(data: Data, urlResponse: URLResponse) -> NetworkService {
        NetworkService(server: .mock, session: .mockSuccess(data: data, urlResponse: urlResponse))
    }
    static func mockError(_ error: Error) -> NetworkService {
        NetworkService(server: .mock, session: .mockError(error))
    }
}

// MARK: - ProductNetworkService

protocol ProductNetworkService {
    func fetchAll() async throws -> [Product]
    func fetchById(_ id: Int) async throws -> Product
    func create(_ product: Product) async throws -> Product
    func update(_ product: Product) async throws -> Product
    func delete(_ id: Int) async throws
}
extension ProductNetworkService {
    static func live(server: HTTPServer) -> NetworkService {
        NetworkService.live(server: server)
    }
    static var mock: MockProductNetworkService {
        MockProductNetworkService()
    }
}

extension NetworkService: ProductNetworkService {

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    // MARK: - Product CRUD Methods
    
    func fetchAll() async throws -> [Product] {
        let request = HTTPRequest.get(path: "products")
        let data = try await dispatch(request: request).data
        return try decoder.decode([Product].self, from: data)
    }

    func fetchById(_ id: Int) async throws -> Product {
        let request = HTTPRequest.get(path: "products/\(id)")
        let data = try await dispatch(request: request).data
        return try decoder.decode(Product.self, from: data)
    }
    
    func create(_ product: Product) async throws -> Product {
        let productPayload = try encoder.encode(product)
        let request = HTTPRequest.post(path: "products", body: productPayload)
        let data = try await dispatch(request: request).data
        return try decoder.decode(Product.self, from: data)
    }

    func update(_ product: Product) async throws -> Product {
        let productPayload = try encoder.encode(product)
        let request = HTTPRequest.put(path: "products/\(product.id)", body: productPayload)
        let data = try await dispatch(request: request).data
        return try decoder.decode(Product.self, from: data)
    }

    func delete(_ id: Int) async throws {
        let request = HTTPRequest.delete(path: "products/\(id)")
        _ = try await dispatch(request: request)
    }
}

// MARK: - MockProductNetworkService

class MockProductNetworkService: ProductNetworkService {
    
    typealias FetchAllHandler = () async throws -> [Product]
    typealias FetchByIdHandler = (_ id: Int) async throws -> Product
    typealias CreateHandler = (_ product: Product) async throws -> Product
    typealias UpdateHandler = (_ product: Product) async throws -> Product
    typealias DeleteHandler = (_ id: Int) async throws -> Void
    
    var fetchAllHandler: FetchAllHandler = { Product.mockArray }
    var fetchByIdHandler: FetchByIdHandler = { _ in Product.mockValue }
    var createHandler: CreateHandler = { $0 }
    var updateHandler: UpdateHandler = { $0 }
    var deleteHandler: DeleteHandler = { _ in }
    
    init() {}
    
    func fetchAll() async throws -> [Product] {
        try await fetchAllHandler()
    }
    
    func fetchById(_ id: Int) async throws -> Product {
        try await fetchByIdHandler(id)
    }
    
    func create(_ product: Product) async throws -> Product {
        try await createHandler(product)
    }
    
    func update(_ product: Product) async throws -> Product {
        try await updateHandler(product)
    }
    
    func delete(_ id: Int) async throws {
        try await deleteHandler(id)
    }
}

// MARK: - ProductRepository


@MainActor
@Observable
class ProductRepository {
    
    private(set) var products = [Product]()
    private let productNetworkService: ProductNetworkService
    
    // MARK: - Initialization
    
    init(
        products: [Product] = [Product](),
        productNetworkService: ProductNetworkService
    ) {
        self.products = products
        self.productNetworkService = productNetworkService
    }
    
    static func live(server: HTTPServer) -> ProductRepository {
        ProductRepository(productNetworkService: NetworkService.live(server: server))
    }
    static var mock: ProductRepository {
        ProductRepository(productNetworkService: MockProductNetworkService())
    }
    
    // MARK: - Public Network Operations
    
    @discardableResult
    func fetchAll() async throws -> [Product] {
        //        try await Task.sleep(for: .seconds(2)) // Simulate network delay
        let fetchedProducts = try await productNetworkService.fetchAll()
        self.products = fetchedProducts
        return fetchedProducts
    }
    
    @discardableResult
    func fetchById(_ id: Int) async throws -> Product {
        let product = try await productNetworkService.fetchById(id)
        self.upsert(product)
        return product
    }
    
    @discardableResult
    func create(_ product: Product) async throws -> Product {
        let createdProduct = try await productNetworkService.create(product)
        self.upsert(createdProduct)
        return createdProduct
    }
    
    @discardableResult
    func update(_ product: Product) async throws -> Product {
        let updatedProduct = try await productNetworkService.update(product)
        self.upsert(updatedProduct)
        return updatedProduct
    }
    
    func delete(_ id: Int) async throws -> Void {
        try await productNetworkService.delete(id)
        products.removeAll { $0.id == id }
    }
    
    // MARK: - Cached Product Access
    func lookup(_ id: Int) -> Product? {
        return products.first(where: { $0.id == id })
    }
    
    private func upsert(_ product: Product) {
        if let index = products.firstIndex(where: { $0.id == product.id }) {
            products[index] = product
        } else {
            products.append(product)
        }
    }
}
