import Foundation
import os.log

private let bundleLogger = Logger(subsystem: "io.mobiledge.CRUD", category: "BundleService")

// MARK: - BundleService

struct BundleService {
    
    /// The "witness" for the loading behavior. This closure property holds the loading logic,
    /// allowing it to be replaced for different contexts (e.g., main bundle, test bundle, network).
    var load: (_ fileName: String, _ ext: String) -> Data?
}

extension BundleService {
    /// The default service instance, configured to load data from the application's main bundle.
    static let `default` = BundleService { fileName, ext in
        guard let url = Bundle.main.url(forResource: fileName, withExtension: ext) else {
            bundleLogger.error("Failed to locate \(fileName).\(ext) in bundle.")
            return nil
        }
        
        do {
            return try Data(contentsOf: url)
        } catch {
            bundleLogger.error("Failed to load data from \(url): \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Generic BundleClient

struct BundleClient<T: Decodable & Identifiable> {
    
    let service: BundleService
    let fileName: String
    let ext: String
    private let decode: (Data) throws -> T

    private init(
        service: BundleService,
        fileName: String,
        ext: String,
        decode: @escaping (Data) throws -> T
    ) {
        self.service = service
        self.fileName = fileName
        self.ext = ext
        self.decode = decode
    }
    
    func load() -> T? {
        guard let data = service.load(fileName, ext) else {
            return nil
        }
        
        do {
            return try decode(data)
        } catch {
            bundleLogger.error("Failed to decode \(T.self) from \(fileName).\(ext): \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - BundleClient Static Factories

extension BundleClient {
    
    /// Creates a client configured to decode JSON files.
    static func json(
        service: BundleService = .default,
        fileName: String = String(describing: T.self),
        decoder: JSONDecoder = JSONDecoder()
    ) -> BundleClient<T> {
        BundleClient(
            service: service,
            fileName: fileName,
            ext: "json",
            decode: { data in try decoder.decode(T.self, from: data) }
        )
    }
    
    /// Creates a client configured to decode Property List (plist) files.
    static func plist(
        service: BundleService = .default,
        fileName: String = String(describing: T.self),
        decoder: PropertyListDecoder = PropertyListDecoder()
    ) -> BundleClient<T> {
        BundleClient(
            service: service,
            fileName: fileName,
            ext: "plist",
            decode: { data in try decoder.decode(T.self, from: data) }
        )
    }
}



// MARK: - Standalone Protocol

// AVOID this for services. While convenient for simple cases, it hides
// dependencies (like the Bundle) and mixes data loading with data modeling,
// which makes testing and maintenance difficult.
protocol JsonBundleLoadable: Decodable {
    static func load() -> Self?
    static var fileName: String { get }
    static var bundle: Bundle { get }
}

protocol PlistBundleLoadable: Decodable {
    static func load() -> Self?
    static var fileName: String { get }
    static var bundle: Bundle { get }
}

extension JsonBundleLoadable {
    static func load() -> Self? {
        return loadJSONFromBundle(bundle, fileName: fileName)
    }
    
    // Default fileName is the name of the conforming type.
    static var fileName: String { String(describing: self) }
    
    static var bundle: Bundle { .main }
}

extension PlistBundleLoadable {
    static func load() -> Self? {
        return loadPlistFromBundle(bundle, fileName: fileName)
    }
    
    // Default fileName is the name of the conforming type.
    static var fileName: String { String(describing: self) }
    
    static var bundle: Bundle { .main }
}

// MARK: - Free Functions

// These functions are pure, stateless, and can be used anywhere. But, lacks context and organization. As your application grows, having many global functions can pollute the global namespac
func loadJSONFromBundle<T: Decodable>(_ bundle: Bundle, fileName: String) -> T? {
    guard let url = bundle.url(forResource: fileName, withExtension: "json") else {
        bundleLogger.error("Could not find JSON resource in bundle: \(fileName, privacy: .public).json")
        return nil
    }
    
    guard let data = try? Data(contentsOf: url) else {
        bundleLogger.error("Could not load data from resource: \(url.path, privacy: .public)")
        return nil
    }
    
    do {
        return try JSONDecoder().decode(T.self, from: data)
    } catch {
        bundleLogger.error("Failed to decode JSON file \(fileName, privacy: .public).json: \(error.localizedDescription)")
        return nil
    }
}

func loadPlistFromBundle<T: Decodable>(_ bundle: Bundle, fileName: String) -> T? {
    guard let url = bundle.url(forResource: fileName, withExtension: "plist") else {
        bundleLogger.error("Could not find Plist resource in bundle: \(fileName, privacy: .public).plist")
        return nil
    }
    
    guard let data = try? Data(contentsOf: url) else {
        bundleLogger.error("Could not load data from resource: \(url.path, privacy: .public)")
        return nil
    }
    
    do {
        return try PropertyListDecoder().decode(T.self, from: data)
    } catch {
        bundleLogger.error("Failed to decode Plist file \(fileName, privacy: .public).plist: \(error.localizedDescription)")
        return nil
    }
}
