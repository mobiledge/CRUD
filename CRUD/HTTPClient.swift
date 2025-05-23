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

// MARK: - Client Errors
enum HTTPError: Error {
    case badHTTPResponse
    case badStatusCode(Int)
}


extension URLRequest {
    init(server: HTTPServer,
         path: HTTPPath,
         method: HTTPMethod = .get,
         headers: [String: String]? = nil,
         body: HTTPBody? = nil) {
        
        let fullURL = server.url.appending(path: path)
        self.init(url: fullURL)
        
        self.httpMethod = method.rawValue
        self.httpBody = body
        
        headers?.forEach { key, value in
            self.setValue(value, forHTTPHeaderField: key)
        }
    }
    
    init(url: URL,
         method: HTTPMethod = .get,
         headers: [String: String]? = nil,
         body: HTTPBody? = nil) {
        
        self.init(url: url)
        
        self.httpMethod = method.rawValue
        self.httpBody = body
        
        headers?.forEach { key, value in
            self.setValue(value, forHTTPHeaderField: key)
        }
    }
    
    static func get(server: HTTPServer,
                    path: HTTPPath,
                    headers: [String: String]? = nil) -> URLRequest {
        return URLRequest(server: server, path: path, method: .get, headers: headers)
    }
    
    static func post(server: HTTPServer,
                     path: HTTPPath,
                     headers: [String: String]? = nil,
                     body: HTTPBody) -> URLRequest {
        return URLRequest(server: server, path: path, method: .post, headers: headers, body: body)
    }
    
    static func put(server: HTTPServer,
                    path: HTTPPath,
                    headers: [String: String]? = nil,
                    body: HTTPBody) -> URLRequest {
        return URLRequest(server: server, path: path, method: .put, headers: headers, body: body)
    }
    
    static func delete(server: HTTPServer,
                       path: HTTPPath,
                       headers: [String: String]? = nil,
                       body: HTTPBody? = nil) -> URLRequest {
        return URLRequest(server: server, path: path, method: .delete, headers: headers, body: body)
    }
}
