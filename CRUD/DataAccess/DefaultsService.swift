import Foundation
import os.log

private let logger = Logger(subsystem: "io.mobiledge.CRUD", category: "Defaults")

// MARK: - DefaultsService (Unchanged)

/// A service that provides the fundamental behaviors for a key-value store.
struct DefaultsService {
    var fetch: (_ key: String) -> Data?
    var save: (_ key: String, _ value: Data) -> Void
    var remove: (_ key: String) -> Void
}

extension DefaultsService {
    static let `default` = DefaultsService(
        fetch: { key in UserDefaults.standard.data(forKey: key) },
        save: { key, value in UserDefaults.standard.set(value, forKey: key) },
        remove: { key in UserDefaults.standard.removeObject(forKey: key) }
    )

    static func mock(initialValues: [String: Data] = [:]) -> DefaultsService {
        var store = initialValues
        return DefaultsService(
            fetch: { key in store[key] },
            save: { key, value in store[key] = value },
            remove: { key in store[key] = nil }
        )
    }
}


// MARK: - 1. Client for Singular JSON Objects (Property Approach)

/// A client for fetching, saving, and removing a single `Codable` object,
/// specifically using the JSON format.
struct JsonDefaultsObjectClient<T: Codable> {
    let service: DefaultsService
    let key: String
    let encoder: JSONEncoder
    let decoder: JSONDecoder
    
    // MARK: - Public API
    
    func fetch() -> T? {
        guard let data = service.fetch(key) else { return nil }
        do {
            return try self.decoder.decode(T.self, from: data)
        } catch {
            logger.error("Failed to decode '\(self.key)': \(error.localizedDescription)")
            return nil
        }
    }
    
    func save(_ entity: T) {
        do {
            let data = try self.encoder.encode(entity)
            service.save(key, data)
        } catch {
            logger.error("Failed to encode '\(self.key)': \(error.localizedDescription)")
        }
    }
    
    func remove() {
        service.remove(key)
    }
}

extension JsonDefaultsObjectClient {
    /// Creates a client configured to store a single object as JSON data.
    static func json(
        service: DefaultsService = .default,
        key: String = String(describing: T.self),
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) -> JsonDefaultsObjectClient<T> {
        // The factory now passes the encoder/decoder objects directly.
        JsonDefaultsObjectClient(
            service: service,
            key: key,
            encoder: encoder,
            decoder: decoder
        )
    }
}


// MARK: - 2. Client for JSON Object Collections (Property Approach)

/// A client for CRUD operations on a collection of `Codable & Identifiable` objects,
/// specifically using the JSON format.
struct JsonDefaultsCollectionClient<T: Codable & Identifiable> {
    let service: DefaultsService
    let key: String
    
    // Properties are now stored directly instead of using closures
    let encoder: JSONEncoder
    let decoder: JSONDecoder

    // MARK: - Public API
    
    func all() -> [T] {
        guard let data = service.fetch(key) else { return [] }
        do {
            // Directly use the decoder property
            return try self.decoder.decode([T].self, from: data)
        } catch {
            logger.error("Failed to decode '\(self.key)': \(error.localizedDescription)")
            return []
        }
    }
    
    func find(id: T.ID) -> T? {
        return all().first { $0.id == id }
    }
    
    func save(_ entity: T) {
        var current = all()
        if let index = current.firstIndex(where: { $0.id == entity.id }) {
            current[index] = entity
        } else {
            current.append(entity)
        }
        replaceAll(with: current)
    }

    func delete(_ entity: T) {
        var current = all()
        current.removeAll { $0.id == entity.id }
        replaceAll(with: current)
    }
    
    func replaceAll(with entities: [T]) {
        do {
            // Directly use the encoder property
            let data = try self.encoder.encode(entities)
            service.save(key, data)
        } catch {
            logger.error("Failed to encode '\(self.key)': \(error.localizedDescription)")
        }
    }

    func deleteAll() {
        service.remove(key)
    }
}


extension JsonDefaultsCollectionClient {
    /// Creates a client configured to store a collection of objects as JSON data.
    static func json(
        service: DefaultsService = .default,
        key: String = String(describing: T.self),
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) -> JsonDefaultsCollectionClient<T> {
        // The factory now passes the encoder/decoder objects directly.
        JsonDefaultsCollectionClient(
            service: service,
            key: key,
            encoder: encoder,
            decoder: decoder
        )
    }
}
