import Foundation

// MARK: - Typealiases
typealias HTTPPath = String
typealias HTTPBody = Data

// MARK: - HTTPMethod
enum HTTPMethod: String {
    case get = "GET", post = "POST", put = "PUT", delete = "DELETE"
}

// MARK: - Server
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

// MARK: - Client
struct HTTPClient {
    var handleRequest: (HTTPPath, HTTPMethod, HTTPBody?) async throws -> Data

    static func live(server: HTTPServer, session: URLSession = .shared) -> HTTPClient {
        HTTPClient { path, method, body in
            var request = URLRequest(url: server.url.appendingPathComponent(path))
            request.httpMethod = method.rawValue
            request.httpBody = body

            var headers = ["Accept": "application/json"]
            if body != nil && method != .get {
                headers["Content-Type"] = "application/json; charset=utf-8"
            }
            request.allHTTPHeaderFields = headers

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

    static func mock(returning data: Data) -> HTTPClient {
        HTTPClient { _, _, _ in
            return data
        }
    }

    static func mock(throwing error: Error) -> HTTPClient {
        HTTPClient { _, _, _ in throw error }
    }
}

// MARK: - Client Helper Methods
extension HTTPClient {
    func get(_ path: HTTPPath) async throws -> Data {
        try await handleRequest(path, .get, nil)
    }

    func post(_ path: HTTPPath, body: HTTPBody?) async throws -> Data {
        try await handleRequest(path, .post, body)
    }

    func put(_ path: HTTPPath, body: HTTPBody?) async throws -> Data {
        try await handleRequest(path, .put, body)
    }

    func delete(_ path: HTTPPath, body: HTTPBody? = nil) async throws -> Data {
        try await handleRequest(path, .delete, body)
    }
}

// MARK: - Client Errors
enum HTTPError: Error {
    case badHTTPResponse
    case badStatusCode(Int)
}
