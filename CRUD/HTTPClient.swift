import Foundation
import os.log

// https://davedelong.com/blog/2020/06/27/http-in-swift-part-1/
// https://github.com/davedelong/extendedswift/tree/main/Sources/HTTP

// MARK: - Typealiases

typealias HTTPPath = String
typealias HTTPRequestBody = Data

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
    var server: HTTPServer? = nil
    var urlComponents = URLComponents()
    var method: HTTPMethod = .get
    var headers: [String: String] = [:]
    var body: HTTPRequestBody?

    // MARK: - Static Helper Methods

    static func get(path: HTTPPath, headers: [String: String] = [:]) -> HTTPRequest {
        var request = HTTPRequest()
        request.urlComponents.path = path
        request.method = .get
        request.headers = headers
        return request
    }

    static func post(path: HTTPPath, body: HTTPRequestBody?, headers: [String: String] = [:]) -> HTTPRequest {
        var request = HTTPRequest()
        request.urlComponents.path = path
        request.method = .post
        request.headers = headers
        request.body = body
        return request
    }

    static func put(path: HTTPPath, body: HTTPRequestBody?, headers: [String: String] = [:]) -> HTTPRequest {
        var request = HTTPRequest()
        request.urlComponents.path = path
        request.method = .put
        request.headers = headers
        request.body = body
        return request
    }

    static func delete(path: HTTPPath, headers: [String: String] = [:]) -> HTTPRequest {
        var request = HTTPRequest()
        request.urlComponents.path = path
        request.method = .delete
        request.headers = headers
        return request
    }
    
    // MARK: -
    func generateURLRequest() throws -> URLRequest {
        guard let server = server else {
            throw HTTPError.custom(reason: "Missing server in HTTPRequest.generateURLRequest()")
        }
        
        let fullURL = server.url.appendingPathComponent(urlComponents.path)

        guard var components = URLComponents(url: fullURL, resolvingAgainstBaseURL: true) else {
            throw HTTPError.custom(reason: "Failed to resolve URLComponents from \(fullURL) in HTTPRequest.generateURLRequest()")
        }
        components.queryItems = urlComponents.queryItems

        guard let finalURL = components.url else {
            throw HTTPError.custom(reason: "Failed to construct final URL from URLComponents in HTTPRequest.generateURLRequest()")
        }

        var urlRequest = URLRequest(url: finalURL)
        urlRequest.httpMethod = method.rawValue
        urlRequest.httpBody = body

        for (headerField, value) in headers {
            urlRequest.setValue(value, forHTTPHeaderField: headerField)
        }

        return urlRequest
    }
}

// MARK: - HTTPError

enum HTTPError: Error, Equatable { // Equatable for easier testing
    case badHTTPResponse
    case badStatusCode(Int)
    case custom(reason: String)
}

// MARK: - URLRequest Extensions

extension URLRequest {
    init(
        server: HTTPServer,
        path: HTTPPath,
        method: HTTPMethod = .get,
        headers: [String: String]? = nil,
        body: HTTPRequestBody? = nil
    ) {
        let fullURL = server.url.appending(path: path) // In Swift 5.7+ path: is deprecated, use appendingPathComponent
        // For broader compatibility or older Swift versions, appendingPathComponent might be better:
        // let fullURL = server.url.appendingPathComponent(path)
        
        self.init(url: fullURL)
        self.httpMethod = method.rawValue
        self.httpBody = body
        headers?.forEach { self.setValue($1, forHTTPHeaderField: $0) }
    }
}

// MARK: - Middleware Definitions
struct NetworkRequestMiddleware {
    var configureRequest: (inout URLRequest) throws -> Void
}

extension NetworkRequestMiddleware {
    static func logRequest() -> NetworkRequestMiddleware {
        NetworkRequestMiddleware { request in
            print("\n--- Network Request ---")
            print("URL: \(request.url?.absoluteString ?? "N/A")")
            print("Method: \(request.httpMethod ?? "N/A")")
            print("Headers: \(request.allHTTPHeaderFields ?? [:])")
            if let data = request.httpBody, let dataString = String(data: data, encoding: .utf8) {
                print("Body: \(dataString)")
            }
            print("---------------------\n")
        }
    }
    
    static func logRequestCompact() -> NetworkRequestMiddleware {
        NetworkRequestMiddleware { request in
            print("➡️ \(request.httpMethod ?? "N/A") \(request.url?.absoluteString ?? "N/A")")
        }
    }

    static func jsonHeaders() -> NetworkRequestMiddleware {
        NetworkRequestMiddleware { request in
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
        }
    }
}

struct NetworkResponseMiddleware {
    var processResponse: (inout (Data, URLResponse)) throws -> Void
}

extension NetworkResponseMiddleware {
    static func validateHTTPStatusCode() -> NetworkResponseMiddleware {
        NetworkResponseMiddleware { result in
            guard let httpResponse = result.1 as? HTTPURLResponse else {
                throw ValidationError.invalidResponse
            }
            let validRange: ClosedRange<Int> = 200...299
            guard validRange.contains(httpResponse.statusCode) else {
                throw ValidationError.badStatusCode(httpResponse.statusCode)
            }
        }
    }

    static func logResponse() -> NetworkResponseMiddleware {
        NetworkResponseMiddleware { result in
            if let httpResponse = result.1 as? HTTPURLResponse {
                print("\n--- Network Response ---")
                print("URL: \(httpResponse.url?.absoluteString ?? "N/A")")
                print("Status Code: \(httpResponse.statusCode)")
                print("Headers: \(httpResponse.allHeaderFields)")
                if let dataString = String(data: result.0, encoding: .utf8) {
                    print("Body: \(dataString)")
                }
                print("----------------------\n")
            }
        }
    }
    
    static func logResponseCompact() -> NetworkResponseMiddleware {
        NetworkResponseMiddleware { result in
            if let response = result.1 as? HTTPURLResponse {
                print("⬅️ \(response.statusCode) \(response.url?.absoluteString ?? "N/A")")
            }
        }
    }
    
    enum ValidationError: Error, LocalizedError {
        case invalidResponse
        case badStatusCode(Int)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "The server returned an invalid or non-HTTP response."
            case .badStatusCode(let statusCode):
                return "The server responded with an unsuccessful status code: \(statusCode)."
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
    
    func dispatch(request: HTTPRequest) async throws -> (Data, URLResponse) {
        
        var req = request
        if req.server == nil {
            req.server = server
        }
        
        var mutableRequest = try req.generateURLRequest()

        for middleware in requestMiddlewares {
            try middleware.configureRequest(&mutableRequest)
        }

        var result = try await session.dispatch(mutableRequest)

        for middleware in responseMiddlewares {
            try middleware.processResponse(&result)
        }

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

    private static let productLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ProductNetworkService", category: "dataProcessing")

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    // MARK: - Private Encoding/Decoding Helpers
    
    private static func decode<T: Decodable>(_ data: Data, as type: T.Type, context: String) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            productLogger.error("Error: Failed to decode \(context). \(error.localizedDescription)")
            throw error
        }
    }

    private static func encode<T: Encodable>(_ value: T, context: String) throws -> Data {
        do {
            return try encoder.encode(value)
        } catch {
            productLogger.error("Error: Failed to encode \(context). \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Product CRUD Methods
    
    func fetchAll() async throws -> [Product] {
        let request = HTTPRequest.get(path: "products")
        let data = try await dispatch(request: request).0
        return try Self.decode(data, as: [Product].self, context: "[Product]")
    }

    func fetchById(_ id: Int) async throws -> Product {
        let request = HTTPRequest.get(path: "products/\(id)")
        let data = try await dispatch(request: request).0
        return try Self.decode(data, as: Product.self, context: "Product id \(id)")
    }
    
    func create(_ product: Product) async throws -> Product {
        let productPayload = try Self.encode(product, context: "product for creation")
        let request = HTTPRequest.post(path: "products", body: productPayload)
        let data = try await dispatch(request: request).0
        return try Self.decode(data, as: Product.self, context: "created Product")
    }

    func update(_ product: Product) async throws -> Product {
        let productPayload = try Self.encode(product, context: "product for update")
        let request = HTTPRequest.put(path: "products/\(product.id)", body: productPayload)
        let data = try await dispatch(request: request).0
        return try Self.decode(data, as: Product.self, context: "updated Product id \(product.id)")
    }

    func delete(_ id: Int) async throws {
        let request = HTTPRequest.get(path: "products/\(id)")
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
