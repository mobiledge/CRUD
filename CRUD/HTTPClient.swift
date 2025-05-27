import Foundation
import os.log

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
    static let local = HTTPServer(staticString: "http://localhost:3000/", description: "Local Development") // Changed description for clarity
    static let mock = HTTPServer(staticString: "https://mock.api/", description: "Mock")
}

// MARK: - HTTPSession

struct HTTPSession {
    var dispatch: (URLRequest) async throws -> Data
    
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "HTTPSession", category: "networking")
    
    static func live(session: URLSession = .shared) -> HTTPSession {
        HTTPSession { request in
            logger.info("Making HTTP request to: \(request.url?.absoluteString ?? "unknown URL")")
            
            do {
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    logger.error("Invalid HTTP response received")
                    throw HTTPError.badHTTPResponse
                }
                
                guard (200..<300).contains(httpResponse.statusCode) else {
                    logger.error("HTTP request failed with status code: \(httpResponse.statusCode)")
                    throw HTTPError.badStatusCode(httpResponse.statusCode)
                }
                
                logger.info("HTTP request successful, received \(data.count) bytes")
                return data
                
            } catch {
                logger.error("HTTP request failed with error: \(error.localizedDescription)")
                throw error // Re-throw the original error to preserve context
            }
        }
    }
    
    static func mockError(_ error: Error) -> HTTPSession {
        HTTPSession { _ in
            throw error
        }
    }
    
    static func mockSuccess(data: Data) -> HTTPSession {
        HTTPSession { _ in
            return data
        }
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
        body: HTTPBody? = nil
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
    let server: HTTPServer
    let session: HTTPSession
    
    init(server: HTTPServer, session: HTTPSession) {
        self.server = server
        self.session = session
    }
    
    func makeRequest(path: HTTPPath,
                     method: HTTPMethod = .get,
                     headers: [String: String]? = nil,
                     body: HTTPBody? = nil) -> URLRequest {
        var defaultHeaders = [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
        
        if let headers = headers {
            defaultHeaders.merge(headers) { _, new in new }
        }
        
        return URLRequest(
            server: server,
            path: path,
            method: method,
            headers: defaultHeaders,
            body: body
        )
    }
    
    func sendRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let data = try await session.dispatch(request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        return (data, response)
    }
    
    func validateResponse(_ response: (Data, URLResponse)) throws {
        // No validation
    }
}

// MARK: - ProductNetworkService
actor ProductNetworkService {
    let networkService: NetworkService
    
    init(networkService: NetworkService) {
        self.networkService = networkService
    }
    
    func fetchAll() async throws -> [Product] {
        let request = await networkService.makeRequest(path: "products")
        let response = try await networkService.sendRequest(request)
        try await networkService.validateResponse(response)
        
        let products = try JSONDecoder().decode([Product].self, from: response.0)
        return products
    }
    
    func fetchById(_ id: Int) async throws -> Product {
        let request = await networkService.makeRequest(path: "products/\(id)")
        let response = try await networkService.sendRequest(request)
        try await networkService.validateResponse(response)
        
        let product = try JSONDecoder().decode(Product.self, from: response.0)
        return product
    }
    
    func create(_ product: Product) async throws -> Product {
        let jsonData = try JSONEncoder().encode(product)
        let request = await networkService.makeRequest(
            path: "products/add",
            method: .post,
            body: jsonData
        )
        
        let response = try await networkService.sendRequest(request)
        try await networkService.validateResponse(response)
        
        let createdProduct = try JSONDecoder().decode(Product.self, from: response.0)
        return createdProduct
    }
    
    func update(_ product: Product) async throws -> Product {
        let jsonData = try JSONEncoder().encode(product)
        let request = await networkService.makeRequest(
            path: "products/\(product.id)",
            method: .put,
            body: jsonData
        )
        
        let response = try await networkService.sendRequest(request)
        try await networkService.validateResponse(response)
        
        let updatedProduct = try JSONDecoder().decode(Product.self, from: response.0)
        return updatedProduct
    }
    
    func delete(_ id: Int) async throws -> Void {
        let request = await networkService.makeRequest(
            path: "products/\(id)",
            method: .delete
        )
        
        let response = try await networkService.sendRequest(request)
        try await networkService.validateResponse(response)
    }
}

// MARK: - ProductRepository
@MainActor
@Observable
class ProductRepository {
    var products = [Product]()
    
    private let productNetworkService: ProductNetworkService
    
    init(productNetworkService: ProductNetworkService) {
        self.productNetworkService = productNetworkService
    }
    
    convenience init(server: HTTPServer = .prod, session: HTTPSession = .live()) {
        let networkService = NetworkService(server: server, session: session)
        let productNetworkService = ProductNetworkService(networkService: networkService)
        self.init(productNetworkService: productNetworkService)
    }
    
    @discardableResult
    func fetchAll() async throws -> [Product] {
        try await Task.sleep(for: .seconds(2))
        let fetchedProducts = try await productNetworkService.fetchAll()
        self.products = fetchedProducts
        return fetchedProducts
    }
    
    @discardableResult
    func fetchById(_ id: Int) async throws -> Product {
        let product = try await productNetworkService.fetchById(id)
        
        if let index = products.firstIndex(where: { $0.id == id }) {
            products[index] = product
        } else {
            products.append(product)
        }
        
        return product
    }
    
    @discardableResult
    func create(_ product: Product) async throws -> Product {
        let createdProduct = try await productNetworkService.create(product)
        products.append(createdProduct)
        return createdProduct
    }
    
    @discardableResult
    func update(_ product: Product) async throws -> Product {
        let updatedProduct = try await productNetworkService.update(product)
        
        if let index = products.firstIndex(where: { $0.id == product.id }) {
            products[index] = updatedProduct
        }
        
        return updatedProduct
    }
    
    @discardableResult
    func delete(_ id: Int) async throws -> Void {
        try await productNetworkService.delete(id)
        products.removeAll { $0.id == id }
    }
}
