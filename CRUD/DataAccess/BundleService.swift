import Foundation
import os.log

// MARK: - Core Service

private let logger = Logger(subsystem: "io.mobiledge.CRUD", category: "BundleService")

/// A service that provides a testable interface for fetching raw data from the main bundle.
struct BundleService: @unchecked Sendable {
    /// A closure that attempts to retrieve data for a given resource name and extension.
    var dataForResource: (_ resource: String, _ ext: String) -> Result<Data, Error>
}

extension BundleService {
    /// The default service implementation that uses `Bundle.main`.
    static let `default` = BundleService { resource, ext in
        Bundle.main.data(forResource: resource, withExtension: ext)
    }
}

// MARK: - Approach 1

// Trade-offs: Direct and explicit setup for a single resource.
// However, this approach is verbose, less reusable, and can lead to scattered configuration as an application grows.
/*
 // Usage Example:
 struct User: Codable { let name: String }
 
 let userClient = BundleClient<User>(
 service: .default,
 resource: "user",
 ext: "json",
 decodeHandler: { data in Result { try JSONDecoder().decode(User.self, from: data) } }
 )
 let userResult = userClient.dataForResource()
 */

// MARK: BundleClient<T>
struct BundleClient<T> {
    let service: BundleService
    let resource: String
    let ext: String
    var decodeHandler: (_ data: Data) -> Result<T, Error>
    
    func dataForResource() -> Result<T, Error> {
        service.dataForResource(resource, ext)
            .flatMap { decodeHandler($0) }
    }
}

// MARK: - Approach 2
/// Protocol-Driven Resource


// MARK: BundleResource
protocol BundleResource {
    static var resourceName: String { get }
    static var resourceExtension: String { get }
    static func decode(from data: Data) -> Result<Self, Error>
}

extension BundleResource where Self: Decodable {
    static var resourceName: String { "\(String(describing: Self.self).lowercased()).json" }
    static var resourceExtension: String { "json" }
    static func decode(from data: Data) -> Result<Self, Error> {
        Result { try JSONDecoder().decode(Self.self, from: data) }
    }
}

/// BundleService + BundleResource
extension BundleService {
    func get<T: BundleResource>(_ resourceType: T.Type) -> Result<T, Error> {
        dataForResource(resourceType.resourceName, resourceType.resourceExtension)
            .flatMap { resourceType.decode(from: $0) }
    }
}

// MARK: BundleResourceCollection
protocol BundleResourceCollection {
    static var resourceName: String { get }
    static var resourceExtension: String { get }
    static func decode(from data: Data) -> Result<[Self], Error>
}

extension BundleResourceCollection where Self: Decodable {
    static var resourceName: String { "\(String(describing: Self.self).lowercased())s" }
    static var resourceExtension: String { "json" }
    static func decode(from data: Data) -> Result<Self, Error> {
        Result { try JSONDecoder().decode(Self.self, from: data) }
    }
}

/// BundleService + BundleResourceCollection
extension BundleService {
    func get<T: BundleResourceCollection>(_ resourceType: T.Type) -> Result<[T], Error> {
        dataForResource(resourceType.resourceName, resourceType.resourceExtension)
            .flatMap { resourceType.decode(from: $0) }
    }
}



// MARK: - Shared Infrastructure

/// Defines custom errors that can occur during bundle operations.
enum BundleError: Error {
    case resourceNotFound(name: String?, extension: String?)
    case dataLoadingFailed(url: URL, underlyingError: Error)
}

extension Bundle {
    /**
     Returns the data for a resource, wrapped in a `Result` type.
     
     - Parameters:
     - name: The name of the resource file.
     - ext: The extension of the resource file.
     - Returns: A `Result` containing the resource's `Data` or a `BundleError`.
     */
    func data(forResource name: String?, withExtension ext: String?) -> Result<Data, Error> {
        guard let url = self.url(forResource: name, withExtension: ext) else {
            logger.error("Resource not found in bundle: \(name ?? "nil").\(ext ?? "nil")")
            return .failure(BundleError.resourceNotFound(name: name, extension: ext))
        }
        
        do {
            let data = try Data(contentsOf: url)
            return .success(data)
        } catch {
            logger.error("Failed to load data from URL \(url): \(error.localizedDescription)")
            return .failure(BundleError.dataLoadingFailed(url: url, underlyingError: error))
        }
    }
}

// MARK: - Approach 3
/// Free Functions:
///   These functions are pure, stateless, and can be used anywhere. But, lacks context and organization. As your application grows, having many global functions can pollute the global namespac
func loadJSONFromBundle<T: Decodable>(_ bundle: Bundle, fileName: String) -> T? {
    guard let url = bundle.url(forResource: fileName, withExtension: "json") else {
        logger.error("Could not find JSON resource in bundle: \(fileName, privacy: .public).json")
        return nil
    }
    
    guard let data = try? Data(contentsOf: url) else {
        logger.error("Could not load data from resource: \(url.path, privacy: .public)")
        return nil
    }
    
    do {
        return try JSONDecoder().decode(T.self, from: data)
    } catch {
        logger.error("Failed to decode JSON file \(fileName, privacy: .public).json: \(error.localizedDescription)")
        return nil
    }
}

func loadPlistFromBundle<T: Decodable>(_ bundle: Bundle, fileName: String) -> T? {
    guard let url = bundle.url(forResource: fileName, withExtension: "plist") else {
        logger.error("Could not find Plist resource in bundle: \(fileName, privacy: .public).plist")
        return nil
    }
    
    guard let data = try? Data(contentsOf: url) else {
        logger.error("Could not load data from resource: \(url.path, privacy: .public)")
        return nil
    }
    
    do {
        return try PropertyListDecoder().decode(T.self, from: data)
    } catch {
        logger.error("Failed to decode Plist file \(fileName, privacy: .public).plist: \(error.localizedDescription)")
        return nil
    }
}

//MARK: Approach 4 - Hybrid
/// This might be most suitable for Bundle comsidering the simplicity.
// Final Recommended Version
extension BundleService {
    /**
     Loads and decodes a JSON resource from the main bundle into a specified Decodable type.
     - Parameters:
        - resource: The name of the resource file.
        - fileExtension: The extension of the resource file (e.g., "json").
        - decoder: The JSONDecoder to use for decoding. Defaults to a new instance.
     - Returns: A `Result` containing the decoded object on success or an `Error` on failure.
    */
    func loadDecodable<T: Decodable>(
        fromResource resource: String,
        withExtension fileExtension: String,
        decoder: JSONDecoder = JSONDecoder()
    ) -> Result<T, Error> {
        
        dataForResource(resource, fileExtension)
            .flatMap { data in
                do {
                    return .success(try decoder.decode(T.self, from: data))
                } catch {
                    logger.error("""
                        Failed to decode \(String(describing: T.self)) \
                        from resource "\(resource).\(fileExtension)". \
                        Error: \(error.localizedDescription)
                        """)
                    return .failure(error)
                }
            }
    }
}

