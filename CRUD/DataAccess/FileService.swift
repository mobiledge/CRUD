import Foundation
import os.log

// MARK: - FileService

struct FileService<T: Codable & Identifiable> {
    let fileURL: URL
    let encoder: JSONEncoder
    let decoder: JSONDecoder
    
    init?(
        fileName: String = String(describing: T.self),
        in directory: FileManager.SearchPathDirectory = .documentDirectory,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        
        guard let dirURL = FileManager.default.urls(for: directory, in: .userDomainMask).first else {
            fileLogger.error("Could not find directory: \(directory.description)")
            return nil
        }
        
        self.fileURL = dirURL.appendingPathComponent(fileName).appendingPathExtension("json")
        self.encoder = encoder
        self.decoder = decoder
    }
    
    // MARK: Read Operations
    
    func all() -> [T] {
        return fetch(from: fileURL, using: decoder) ?? []
    }
    
    func all(where predicate: (T) -> Bool) -> [T] {
        return all().filter(predicate)
    }
    
    func find(id: T.ID) -> T? {
        return all().first { $0.id == id }
    }
    
    func find(where predicate: (T) -> Bool) -> T? {
        return all().first(where: predicate)
    }
    
    // MARK: Write Operations
    
    func save(_ entity: T) {
        var current = all()
        if let index = current.firstIndex(where: { $0.id == entity.id }) {
            current[index] = entity
        } else {
            current.append(entity)
        }
        replaceAll(with: current)
    }
    
    func saveMany(upserting entities: [T]) {
        guard !entities.isEmpty else { return }
        let current = all()
        var currentDict = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
        for entity in entities {
            currentDict[entity.id] = entity
        }
        replaceAll(with: Array(currentDict.values))
    }
    
    func replaceAll(with entities: [T]) {
        persist(entities, to: fileURL, using: encoder)
    }
    
    // MARK: Delete Operations
    
    func delete(_ entity: T) {
        var current = all()
        current.removeAll { $0.id == entity.id }
        replaceAll(with: current)
    }
    
    func delete(subset entities: [T]) {
        guard !entities.isEmpty else { return }
        var current = all()
        let idsToDelete = Set(entities.map { $0.id })
        current.removeAll { idsToDelete.contains($0.id) }
        replaceAll(with: current)
    }
    
    func deleteAll() {
        remove(at: fileURL)
    }
}

// MARK: - FileServicable

protocol FileServicable: Codable, Identifiable {
    // Read
    static func all() -> [Self]
    static func all(where predicate: (Self) -> Bool) -> [Self]
    static func find(id: Self.ID) -> Self?
    static func find(where predicate: (Self) -> Bool) -> Self?
    
    // Write
    func save()
    static func saveMany(upserting entities: [Self])
    static func replaceAll(with entities: [Self])
    
    // Delete
    func delete()
    static func delete(subset entities: [Self])
    static func deleteAll()
    
    // Convenience properties
    static var fileName: String { get }
    static var directory: FileManager.SearchPathDirectory { get }
    static var encoder: JSONEncoder { get }
    static var decoder: JSONDecoder { get }
}

// MARK: - FileServicable Extension

extension FileServicable {
    static var fileName: String { String(describing: Self.self) }
    static var directory: FileManager.SearchPathDirectory { .documentDirectory }
    static var encoder: JSONEncoder { JSONEncoder() }
    static var decoder: JSONDecoder { JSONDecoder() }
    
    private static var service: FileService<Self>? {
        FileService(fileName: fileName, in: directory, encoder: encoder, decoder: decoder)
    }
    
    // Default implementations
    static func all() -> [Self] { service?.all() ?? [] }
    static func all(where predicate: (Self) -> Bool) -> [Self] { service?.all(where: predicate) ?? [] }
    static func find(id: Self.ID) -> Self? { service?.find(id: id) }
    static func find(where predicate: (Self) -> Bool) -> Self? { service?.find(where: predicate) }
    
    func save() { Self.service?.save(self) }
    static func saveMany(upserting entities: [Self]) { service?.saveMany(upserting: entities) }
    static func replaceAll(with entities: [Self]) { service?.replaceAll(with: entities) }
    
    func delete() { Self.service?.delete(self) }
    static func delete(subset entities: [Self]) { service?.delete(subset: entities) }
    static func deleteAll() { service?.deleteAll() }
}

// MARK: - Private Free Functions

private let fileLogger = Logger(subsystem: "io.mobiledge.CRUD", category: "FileService")

private func fetch<T: Decodable>(from url: URL, using decoder: JSONDecoder) -> T? {
    guard FileManager.default.fileExists(atPath: url.path) else {
        fileLogger.debug("No file found at path: \(url.path, privacy: .public)")
        return nil
    }
    
    do {
        let data = try Data(contentsOf: url)
        return try decoder.decode(T.self, from: data)
    } catch {
        fileLogger.error("Failed to decode data from path \(url.path, privacy: .public): \(error.localizedDescription)")
        return nil
    }
}

@discardableResult
private func persist<T: Encodable>(_ value: T, to url: URL, using encoder: JSONEncoder) -> Bool {
    do {
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
        fileLogger.debug("Successfully persisted value to path: \(url.path, privacy: .public)")
        return true
    } catch {
        fileLogger.error("Failed to encode or save value to path \(url.path, privacy: .public): \(error.localizedDescription)")
        return false
    }
}

private func remove(at url: URL) {
    guard FileManager.default.fileExists(atPath: url.path) else { return }
    do {
        try FileManager.default.removeItem(at: url)
        fileLogger.debug("Successfully removed file at path: \(url.path, privacy: .public)")
    } catch {
        fileLogger.error("Failed to remove file at path \(url.path, privacy: .public): \(error.localizedDescription)")
    }
}

// Helper for describing search path directories in logs
extension FileManager.SearchPathDirectory {
    var description: String {
        switch self {
        case .documentDirectory: return "DocumentDirectory"
        case .cachesDirectory: return "CachesDirectory"
        case .applicationSupportDirectory: return "ApplicationSupportDirectory"
        default: return "OtherDirectory"
        }
    }
}
