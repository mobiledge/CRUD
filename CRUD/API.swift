import Foundation

// MARK: - Typealiases
typealias Path = String
typealias Body = Data

// MARK: - HTTPMethod
enum HTTPMethod: String {
    case get = "GET", post = "POST", put = "PUT", delete = "DELETE"
}

// MARK: - Server
struct Server {
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

    static let prod = Server(staticString: "https://dummyjson.com/", description: "Production")
    static let mock = Server(staticString: "https://mock.api/", description: "Mock")
}

// MARK: - Client
struct Client {
    var handleRequest: (Path, HTTPMethod, Body?) async throws -> Data

    static func live(server: Server, session: URLSession = .shared) -> Client {
        Client { path, method, body in
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
                throw ClientError.invalidResponse
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw ClientError.badStatusCode(httpResponse.statusCode, data)
            }
            return data
        }
    }

    static func mock(returning data: Data) -> Client {
        Client { _, _, _ in
            return data
        }
    }

    static func mock(throwing error: Error) -> Client {
        Client { _, _, _ in throw error }
    }
}

// MARK: - Client Errors
enum ClientError: Error {
    case invalidResponse
    case badStatusCode(Int, Data)
}

// MARK: - Client Helper Methods
extension Client {
    func get(_ path: Path) async throws -> Data {
        try await handleRequest(path, .get, nil)
    }

    func post(_ path: Path, body: Body?) async throws -> Data {
        try await handleRequest(path, .post, body)
    }

    func put(_ path: Path, body: Body?) async throws -> Data {
        try await handleRequest(path, .put, body)
    }

    func delete(_ path: Path, body: Body? = nil) async throws -> Data {
        try await handleRequest(path, .delete, body)
    }
}
