import Foundation
import os.log

private let bundleLogger = Logger(subsystem: "io.mobiledge.CRUD", category: "BundleLoader")

protocol JsonBundleLoadable: Decodable {
    static func load() -> Self?
    static var fileName: String { get }
}

protocol PlistBundleLoadable: Decodable {
    static func load() -> Self?
    static var fileName: String { get }
}

// MARK: -
extension JsonBundleLoadable {
    static func load() -> Self? {
        return loadJSON(from: fileName)
    }

    // Default fileName is the name of the conforming type.
    static var fileName: String {
        return String(describing: self)
    }
}

extension PlistBundleLoadable {
    static func load() -> Self? {
        return loadPlist(from: fileName)
    }

    // Default fileName is the name of the conforming type.
    static var fileName: String {
        return String(describing: self)
    }
}


// MARK: - Free Functions

func loadJSON<T: Decodable>(from fileName: String) -> T? {
    guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
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

func loadPlist<T: Decodable>(from fileName: String) -> T? {
    guard let url = Bundle.main.url(forResource: fileName, withExtension: "plist") else {
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

