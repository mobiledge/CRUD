import Foundation
import os.log

private let logger = Logger(subsystem: "io.mobiledge.CRUD", category: "UserDefaultsService")

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
    
    func all() -> [T] {
        guard let data = defaults.data(forKey: key) else {
            logger.debug("No data found for key: \(self.key)")
            return []
        }
        do {
            return try decoder.decode([T].self, from: data)
        } catch {
            logger.error("Failed to decode data for key \(self.key): \(error.localizedDescription)")
            return []
        }
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
    func save(_ entity: T) {
        var current = all()
        if let index = current.firstIndex(where: { $0.id == entity.id }) {
            current[index] = entity
        } else {
            current.append(entity)
        }
        saveMany(current)
    }
    func saveMany(_ entities: [T]) {
        do {
            let data = try encoder.encode(entities)
            defaults.set(data, forKey: key)
            logger.debug("Successfully saved \(entities.count) entities for key: \(self.key)")
        } catch {
            logger.error("Failed to encode or save entities for key \(self.key): \(error.localizedDescription)")
        }
    }
    func delete(_ entity: T) {
        var current = all()
        current.removeAll { $0.id == entity.id }
        saveMany(current)
    }
    func deleteMany(_ entities: [T]) {
        var current = all()
        let idsToDelete = entities.map { $0.id }
        current.removeAll { idsToDelete.contains($0.id) }
        saveMany(current)
    }
}

protocol DefaultsServicable: Codable & Identifiable {
    static var key: String { get }
    static var defaults: UserDefaults { get }
    static var encoder: JSONEncoder { get }
    static var decoder: JSONDecoder { get }
    
    static func all() -> [Self]
    static func all(where predicate: (Self) -> Bool) -> [Self]
    static func find(id: Self.ID) -> Self?
    static func find(where predicate: (Self) -> Bool) -> Self?
    func save()
    static func saveMany(_ entities: [Self])
    func delete()
    static func deleteMany(_ entities: [Self])
}

extension DefaultsServicable {
    // Default static implementations
    static var key: String { String(describing: Self.self) }
    static var defaults: UserDefaults { .standard }
    static var encoder: JSONEncoder { JSONEncoder() }
    static var decoder: JSONDecoder { JSONDecoder() }
    
    private static var service: DefaultsService<Self> {
        DefaultsService(
            key: key,
            defaults: defaults,
            encoder: encoder,
            decoder: decoder
        )
    }
    
    static func all() -> [Self] {
        service.all()
    }
    
    static func all(where predicate: (Self) -> Bool) -> [Self] {
        service.all(where: predicate)
    }
    
    static func find(id: Self.ID) -> Self? {
        service.find(id: id)
    }
    
    static func find(where predicate: (Self) -> Bool) -> Self? {
        service.find(where: predicate)
    }
    
    func save() {
        Self.service.save(self)
    }
    
    static func saveMany(_ entities: [Self]) {
        service.saveMany(entities)
    }
    
    func delete() {
        Self.service.delete(self)
    }
    
    static func deleteMany(_ entities: [Self]) {
        service.deleteMany(entities)
    }
}


// MARK: - Product + UserDefaultsResource

extension Product: DefaultsServicable {}
