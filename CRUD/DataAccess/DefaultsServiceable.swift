import Foundation
import os.log

// MARK: - DefaultsServicable

protocol DefaultsServicable: Codable, Identifiable {
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
    static var key: String { get }
    static var defaults: UserDefaults { get }
    static var encoder: JSONEncoder { get }
    static var decoder: JSONDecoder { get }
}

// MARK: - DefaultsService

struct DefaultsService<T: Codable & Identifiable> {
    let key: String
    let defaults: UserDefaults
    let encoder: JSONEncoder
    let decoder: JSONDecoder
    
    init(key: String = String(describing: T.self),
         defaults: UserDefaults = .standard,
         encoder: JSONEncoder = JSONEncoder(),
         decoder: JSONDecoder = JSONDecoder()) {
        self.key = key
        self.defaults = defaults
        self.encoder = encoder
        self.decoder = decoder
    }
    
    // MARK: Read Operations
    
    func all() -> [T] {
        return fetch(from: defaults, forKey: key, using: decoder) ?? []
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
        persist(entities, to: defaults, forKey: key, using: encoder)
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
        remove(forKey: key, from: defaults)
    }
}

// MARK: - DefaultsServicable Extension

extension DefaultsServicable {
    static var key: String { String(describing: Self.self) }
    static var defaults: UserDefaults { .standard }
    static var encoder: JSONEncoder { JSONEncoder() }
    static var decoder: JSONDecoder { JSONDecoder() }
    
    private static var service: DefaultsService<Self> {
        DefaultsService(key: key, defaults: defaults, encoder: encoder, decoder: decoder)
    }
    
    // Default implementations
    static func all() -> [Self] { service.all() }
    static func all(where predicate: (Self) -> Bool) -> [Self] { service.all(where: predicate) }
    static func find(id: Self.ID) -> Self? { service.find(id: id) }
    static func find(where predicate: (Self) -> Bool) -> Self? { service.find(where: predicate) }
    
    func save() { Self.service.save(self) }
    static func saveMany(upserting entities: [Self]) { service.saveMany(upserting: entities) }
    static func replaceAll(with entities: [Self]) { service.replaceAll(with: entities) }
    
    func delete() { Self.service.delete(self) }
    static func delete(subset entities: [Self]) { service.delete(subset: entities) }
    static func deleteAll() { Self.service.deleteAll() }
}

// MARK: - Example Usage
/*
 struct Product: Codable, Identifiable {
 var id: Int
 var name: String
 }
 extension Product: DefaultsServicable {}
 */


// MARK: - Private Free Functions

private let logger = Logger(subsystem: "io.mobiledge.CRUD", category: "UserDefaultsService")

private func fetch<T: Decodable>(from defaults: UserDefaults, forKey key: String, using decoder: JSONDecoder) -> T? {
    guard let data = defaults.data(forKey: key) else {
        logger.debug("No data found for key: \(key, privacy: .public)")
        return nil
    }
    do {
        return try decoder.decode(T.self, from: data)
    } catch {
        logger.error("Failed to decode data for key \(key, privacy: .public): \(error.localizedDescription)")
        return nil
    }
}

@discardableResult
private func persist<T: Encodable>(_ value: T, to defaults: UserDefaults, forKey key: String, using encoder: JSONEncoder) -> Bool {
    do {
        let data = try encoder.encode(value)
        defaults.set(data, forKey: key)
        logger.debug("Successfully persisted value for key: \(key, privacy: .public)")
        return true
    } catch {
        logger.error("Failed to encode or save value for key \(key, privacy: .public): \(error.localizedDescription)")
        return false
    }
}

private func remove(forKey key: String, from defaults: UserDefaults) {
    defaults.removeObject(forKey: key)
    logger.debug("Successfully removed object for key: \(key, privacy: .public)")
}
