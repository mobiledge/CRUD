import Foundation
import os.log

private let logger = Logger(subsystem: "io.mobiledge.CRUD", category: "DefaultsService")

// MARK: - DefaultsService

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


// MARK: - DefaultsClient

/// A client for fetching, saving, and removing a single `Codable` object,
/// specifically using the JSON format.
struct DefaultsClient<T: Codable> {
    let service: DefaultsService
    let key: String
    let encoder: JSONEncoder
    let decoder: JSONDecoder
    
    init(
        service: DefaultsService = .default,
        key: String = String(describing: T.self),
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.service = service
        self.key = key
        self.encoder = encoder
        self.decoder = decoder
    }
    
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
