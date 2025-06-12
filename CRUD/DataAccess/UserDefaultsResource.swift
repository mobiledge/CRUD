import Foundation

protocol UserDefaultsResource: Codable & Identifiable {
    
    static var ud_key: String { get }
    static var ud_defaults: UserDefaults { get }
    static var ud_encoder: JSONEncoder { get }
    static var ud_decoder: JSONDecoder { get }

    static func ud_fetchAll() throws -> [Self]
    static func ud_fetchById(_ id: ID) throws -> Self
    static func ud_create(_ entity: Self) throws -> Self
    static func ud_update(_ entity: Self) throws -> Self
    static func ud_delete(_ id: ID) throws

    func ud_create() throws -> Self
    func ud_update() throws -> Self
    func ud_delete() throws
}

extension UserDefaultsResource {

    static var ud_key: String { "ud_\(String(describing: self))" }
    static var ud_defaults: UserDefaults { .standard }
    static var ud_encoder: JSONEncoder { JSONEncoder() }
    static var ud_decoder: JSONDecoder { JSONDecoder() }

    // MARK: - Static Methods

    static func ud_fetchAll() throws -> [Self] {
        guard let data = ud_defaults.data(forKey: ud_key) else {
            return []
        }
        return try ud_decoder.decode([Self].self, from: data)
    }

    static func ud_fetchById(_ id: ID) throws -> Self {
        let all = try ud_fetchAll()
        guard let found = all.first(where: { $0.id == id }) else {
            throw NSError(domain: "UserDefaultsResource", code: 404, userInfo: [NSLocalizedDescriptionKey: "Item not found"])
        }
        return found
    }

    static func ud_create(_ entity: Self) throws -> Self {
        var all = try ud_fetchAll()
        guard !all.contains(where: { $0.id == entity.id }) else {
            throw NSError(domain: "UserDefaultsResource", code: 409, userInfo: [NSLocalizedDescriptionKey: "Item already exists"])
        }
        all.append(entity)
        try save(all)
        return entity
    }

    static func ud_update(_ entity: Self) throws -> Self {
        var all = try ud_fetchAll()
        guard let index = all.firstIndex(where: { $0.id == entity.id }) else {
            throw NSError(domain: "UserDefaultsResource", code: 404, userInfo: [NSLocalizedDescriptionKey: "Item not found"])
        }
        all[index] = entity
        try save(all)
        return entity
    }

    static func ud_delete(_ id: ID) throws {
        var all = try ud_fetchAll()
        guard let index = all.firstIndex(where: { $0.id == id }) else {
            throw NSError(domain: "UserDefaultsResource", code: 404, userInfo: [NSLocalizedDescriptionKey: "Item not found"])
        }
        all.remove(at: index)
        try save(all)
    }

    private static func save(_ all: [Self]) throws {
        let data = try ud_encoder.encode(all)
        ud_defaults.set(data, forKey: ud_key)
    }

    // MARK: - Instance Methods

    func ud_create() throws -> Self {
        return try Self.ud_create(self)
    }

    func ud_update() throws -> Self {
        return try Self.ud_update(self)
    }

    func ud_delete() throws {
        try Self.ud_delete(self.id)
    }
}

// MARK: - Product + UserDefaultsResource

extension Product: UserDefaultsResource {}
