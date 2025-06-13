import Foundation
import os.log

private let bundleLogger = Logger(subsystem: "io.mobiledge.CRUD", category: "BundleLoader")

// MARK: - BundleService

// BEST APPROACH: Use this service class. It cleanly encapsulates logic and
// dependencies, making it easy to test, maintain, and scale.
final class BundleService {
    
    let bundle: Bundle
    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }
    
    func loadJSON<T: Decodable>(from fileName: String) -> T? {
        loadJSONFromBundle(bundle, fileName: fileName)
    }
    
    func loadPlist<T: Decodable>(from fileName: String) -> T? {
        loadPlistFromBundle(bundle, fileName: fileName)
    }
}

// MARK: - Standalone Protocols

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
private func loadJSONFromBundle<T: Decodable>(_ bundle: Bundle, fileName: String) -> T? {
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

private func loadPlistFromBundle<T: Decodable>(_ bundle: Bundle, fileName: String) -> T? {
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
