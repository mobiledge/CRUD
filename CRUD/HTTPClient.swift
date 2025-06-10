import Foundation
import os.log

// https://davedelong.com/blog/2020/06/27/http-in-swift-part-1/
// https://github.com/davedelong/extendedswift/tree/main/Sources/HTTP

// MARK: - Typealiases

typealias HTTPPath = String
typealias HTTPRequestBody = Data
typealias HTTPResponseBody = Data

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

// MARK: - HTTPResponse
struct HTTPResponse {
    let body: HTTPResponseBody
    let response: HTTPURLResponse

    init(body: HTTPRequestBody, response: HTTPURLResponse) {
        self.body = body
        self.response = response
    }

    init(body: HTTPRequestBody, urlResponse: URLResponse) throws {
        guard let response = urlResponse as? HTTPURLResponse else {
            throw HTTPResponseError.failedToCastToHTTPURLResponse
        }
        self.init(body: body, response: response)
    }

    /// Throws if the status code is not in the 200–299 range.
    func validateStatusCode() throws {
        guard (200...299).contains(response.statusCode) else {
            throw HTTPResponseError.invalidStatusCode(code: response.statusCode)
        }
    }

    enum HTTPResponseError: Error, LocalizedError {
        case failedToCastToHTTPURLResponse
        case invalidStatusCode(code: Int)

        var errorDescription: String? {
            switch self {
            case .failedToCastToHTTPURLResponse:
                return "Failed to cast URLResponse to HTTPURLResponse."
            case .invalidStatusCode(let code):
                return "Invalid HTTP status code: \(code)"
            }
        }
    }
}

// MARK: - HTTPResponseBody
extension HTTPResponseBody {
    func decoded<T>(as type: T.Type, decoder: JSONDecoder = JSONDecoder()) throws -> T where T : Decodable {
        try decoder.decode(type, from: self)
    }
}


// MARK: - HTTPError

enum HTTPError: Error, Equatable { // Equatable for easier testing
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

// MARK: - NetworkService

actor NetworkService {
    private let server: HTTPServer
    private let session: HTTPSession
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "NetworkService", category: "networking")

    private init(server: HTTPServer, session: HTTPSession) {
        self.server = server
        self.session = session
    }
    
    func dispatch(urlRequest: URLRequest) async throws -> HTTPResponseBody {
        var mutableRequest = urlRequest
        configureRequest(&mutableRequest)
        
        NetworkService.logger.info("Dispatch: \(mutableRequest.httpMethod ?? "N/A") \(mutableRequest.url?.absoluteString ?? "unknown URL")")
        
        let (data, urlResponse) = try await session.dispatch(mutableRequest)
        let response = try HTTPResponse(body: data, urlResponse: urlResponse)
        try response.validateStatusCode()
        return response.body
    }
    
    private func configureRequest(_ request: inout URLRequest) {
        // Content-Type: What I'm Sending You
        // Specifies the media type of the resource in the body of the HTTP message.
        if request.value(forHTTPHeaderField: "Content-Type") == nil {
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        }
        
        // "Accept": What I Can Understand
        // Indicates what media types the client is capable of understanding and willing to receive in the response.
        if request.value(forHTTPHeaderField: "Accept") == nil {
            request.setValue("application/json", forHTTPHeaderField: "Accept")
        }
    }
}

extension NetworkService {
    func get(path: HTTPPath, headers: [String: String]? = nil) async throws -> Data {
        let request = URLRequest(server: self.server, path: path, method: .get, headers: headers)
        return try await dispatch(urlRequest: request)
    }
    
    func post(path: HTTPPath, headers: [String: String]? = nil, body: HTTPRequestBody) async throws -> Data {
        let request = URLRequest(server: self.server, path: path, method: .post, headers: headers, body: body)
        return try await dispatch(urlRequest: request)
    }
    
    func put(path: HTTPPath, headers: [String: String]? = nil, body: HTTPRequestBody) async throws -> Data {
        let request = URLRequest(server: self.server, path: path, method: .put, headers: headers, body: body)
        return try await dispatch(urlRequest: request)
    }
    
    func delete(path: HTTPPath, headers: [String: String]? = nil) async throws -> Data {
        let request = URLRequest(server: self.server, path: path, method: .delete, headers: headers)
        return try await dispatch(urlRequest: request)
    }
}

extension NetworkService {
    static func live(server: HTTPServer) -> NetworkService {
        NetworkService(server: server, session: .live())
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
        let data = try await get(path: "products")
        return try Self.decode(data, as: [Product].self, context: "[Product]")
    }

    func fetchById(_ id: Int) async throws -> Product {
        let data = try await get(path: "products/\(id)")
        return try Self.decode(data, as: Product.self, context: "Product id \(id)")
    }
    
    func create(_ product: Product) async throws -> Product {
        let productData = try Self.encode(product, context: "product for creation")
        let responseData = try await post(path: "products", body: productData)
        return try Self.decode(responseData, as: Product.self, context: "created Product")
    }

    func update(_ product: Product) async throws -> Product {
        let productPayload = try Self.encode(product, context: "product for update")
        let responseData = try await put(path: "products/\(product.id)", body: productPayload)
        return try Self.decode(responseData, as: Product.self, context: "updated Product id \(product.id)")
    }

    func delete(_ id: Int) async throws {
        _ = try await delete(path: "products/\(id)")
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
