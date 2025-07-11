import Foundation
import os.log
import Observation

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

    static func live(session: URLSession = .shared) -> HTTPSession {
        HTTPSession { request in
            try await session.data(for: request)
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

// MARK: - HTTPMethod

enum HTTPMethod: String {
    case get = "GET", post = "POST", put = "PUT", delete = "DELETE"
}

// MARK: - HTTPRequestBody

struct HTTPRequestBody {
    let additionalHeaders: [String: String]
    let data: Data

    static func json<T: Encodable>(_ value: T, encoder: JSONEncoder = JSONEncoder()) throws -> HTTPRequestBody {
        let headers = ["Content-Type": "application/json; charset=utf-8"]
        let data = try encoder.encode(value)
        return HTTPRequestBody(additionalHeaders: headers, data: data)
    }

    static func form(items: [URLQueryItem]) -> HTTPRequestBody {
        let headers = ["Content-Type": "application/x-www-form-urlencoded; charset=utf-8"]
        var components = URLComponents()
        components.queryItems = items
        let urlEncodedString = components.query ?? ""
        let data = Data(urlEncodedString.utf8)
        return HTTPRequestBody(additionalHeaders: headers, data: data)
    }
}

// MARK: - HTTPRequest

struct HTTPRequest {
    var server: HTTPServer?
    var path: String = "/"
    var queryItems: [URLQueryItem] = []
    var method: HTTPMethod = .get
    var headers: [String: String] = [:]
    var body: HTTPRequestBody?

    /// Fluent Interface

    func server(_ server: HTTPServer) -> Self {
        var newRequest = self
        newRequest.server = server
        return newRequest
    }

    func path(_ path: String) -> Self {
        var newRequest = self
        newRequest.path = path
        return newRequest
    }

    func queryItems(_ queryItems: [URLQueryItem]) -> Self {
        var newRequest = self
        newRequest.queryItems = queryItems
        return newRequest
    }

    func method(_ method: HTTPMethod) -> Self {
        var newRequest = self
        newRequest.method = method
        return newRequest
    }
    
    func header(key: String, value: String) -> Self {
        var newRequest = self
        newRequest.headers[key] = value
        return newRequest
    }

    func headers(_ headers: [String: String]) -> Self {
        var newRequest = self
        newRequest.headers.merge(headers) { (_, new) in new }
        return newRequest
    }

    func body(_ body: HTTPRequestBody) -> Self {
        var newRequest = self
        newRequest.body = body
        // Automatically merge headers from the body into the request's headers
        if let bodyHeaders = newRequest.body?.additionalHeaders {
            newRequest.headers.merge(bodyHeaders) { (_, new) in new }
        }
        return newRequest
    }

    /// Static Helper Methods

    static func get(path: String) -> HTTPRequest {
        HTTPRequest()
            .method(.get)
            .path(path)
    }

    static func post(path: String, body: HTTPRequestBody) -> HTTPRequest {
        HTTPRequest()
            .method(.post)
            .path(path)
            .body(body)
    }

    static func put(path: String, body: HTTPRequestBody) -> HTTPRequest {
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

    /// URLRequest Generation

    func generateURLRequest() throws -> URLRequest {
        guard let server = server else {
            throw HTTPError.badRequest(reason: "Server not set for the request.")
        }
        var finalURL = server.url
        finalURL.appendPathComponent(self.path)
        if !queryItems.isEmpty {
            finalURL.append(queryItems: self.queryItems)
        }
        var urlRequest = URLRequest(url: finalURL)
        urlRequest.httpMethod = method.rawValue
        urlRequest.httpBody = body?.data
        urlRequest.allHTTPHeaderFields = headers
        return urlRequest
    }
}

// MARK: - HTTPResponse

struct HTTPResponse {
    let data: Data
    let response: URLResponse
}

// MARK: - NetworkService

actor NetworkService {
    private let server: HTTPServer
    private let session: HTTPSession
    private let logger: Logger

    init(
        server: HTTPServer,
        session: HTTPSession,
        logger: Logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.yourapp", category: "Networking")
    ) {
        self.server = server
        self.session = session
        self.logger = logger
    }

    func dispatch(request: HTTPRequest) async throws -> HTTPResponse {
        // 1. Assign default server if needed.
        var req = request
        if req.server == nil {
            req = req.server(server)
        }
        
        // 2. Log the outgoing request.
        let serverURL = req.server?.url.absoluteString ?? "N/A"
        let method = req.method.rawValue
        let fullPath = "\(serverURL)\(req.path)"
        logger.debug("➡️ \(method) \(fullPath)")
        
        // 3. Generate the final URLRequest and send it.
        let urlRequest = try req.generateURLRequest()
        let (data, urlResponse) = try await session.dispatch(urlRequest)
        
        // 4. Log and validate the incoming response.
        if let resp = urlResponse as? HTTPURLResponse, let url = resp.url {
            logger.debug("⬅️ \(resp.statusCode) \(url.absoluteString)")
            guard (200...299).contains(resp.statusCode) else {
                throw HTTPError.badStatusCode(resp.statusCode)
            }
        } else {
            logger.debug("⬅️ Received a non-HTTP response.")
            throw HTTPError.badHTTPResponse
        }
        
        return HTTPResponse(data: data, response: urlResponse)
    }
}

extension NetworkService {
    static func live(server: HTTPServer) -> NetworkService {
        NetworkService(
            server: server,
            session: .live()
        )
    }
    static func mockSuccess(data: Data, urlResponse: URLResponse) -> NetworkService {
        NetworkService(server: .mock, session: .mockSuccess(data: data, urlResponse: urlResponse))
    }
    static func mockError(_ error: Error) -> NetworkService {
        NetworkService(server: .mock, session: .mockError(error))
    }
}

// MARK: - HTTPError

enum HTTPError: Error, Equatable {
    case invalidServerURL
    case badRequest(reason: String)
    case badHTTPResponse
    case badStatusCode(Int)
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
        let requestBody = try HTTPRequestBody.json(product, encoder: encoder)
        let request = HTTPRequest.post(path: "products", body: requestBody)
        let data = try await dispatch(request: request).data
        return try decoder.decode(Product.self, from: data)
    }

    func update(_ product: Product) async throws -> Product {
        let requestBody = try HTTPRequestBody.json(product, encoder: encoder)
        let request = HTTPRequest.put(path: "products/\(product.id)", body: requestBody)
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

    /// Initialization

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

    /// Public Network Operations

    @discardableResult
    func fetchAll() async throws -> [Product] {
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

    /// Cached Product Access
    
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
