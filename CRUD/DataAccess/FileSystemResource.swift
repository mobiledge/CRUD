import Foundation

protocol FileSystemResource: Codable & Identifiable {
    static var fs_encoder: JSONEncoder { get }
    static var fs_decoder: JSONDecoder { get }
    
    /// Defaults to `.documentDirectory`
    static var fs_baseDirectory: FileManager.SearchPathDirectory { get }
    /// Defaults to the type name as the subdirectory (e.g., "Product")
    static var fs_subdirectory: String { get }

    static func fs_fetchAll() throws -> [Self]
    static func fs_fetchById(_ id: ID) throws -> Self
    static func fs_create(_ entity: Self) throws -> Self
    static func fs_createMany(_ entities: [Self]) throws -> [Self]
    static func fs_update(_ entity: Self) throws -> Self
    static func fs_updateMany(_ entities: [Self]) throws -> [Self]
    static func fs_delete(_ id: ID) throws
    static func fs_deleteMany(_ ids: [ID]) throws

    func fs_create() throws -> Self
    func fs_update() throws -> Self
    func fs_delete() throws
}

extension FileSystemResource {

    static var fs_encoder: JSONEncoder { JSONEncoder() }
    static var fs_decoder: JSONDecoder { JSONDecoder() }

    static var fs_baseDirectory: FileManager.SearchPathDirectory { .documentDirectory }
    
    static var fs_subdirectory: String { String(describing: Self.self) }

    static var fs_directory: URL {
        let paths = FileManager.default.urls(for: fs_baseDirectory, in: .userDomainMask)
        guard let base = paths.first else {
            fatalError("Unable to access file system base directory.")
        }
        let dir = base.appendingPathComponent(fs_subdirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        return dir
    }

    private static func fileURL(for id: ID) -> URL {
        fs_directory.appendingPathComponent("\(id).json")
    }

    // MARK: - Fetch

    static func fs_fetchAll() throws -> [Self] {
        let files = try FileManager.default.contentsOfDirectory(at: fs_directory, includingPropertiesForKeys: nil)
        return try files.map { try fs_decoder.decode(Self.self, from: Data(contentsOf: $0)) }
    }

    static func fs_fetchById(_ id: ID) throws -> Self {
        let url = fileURL(for: id)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw NSError(domain: "FileSystemResource", code: 404, userInfo: [NSLocalizedDescriptionKey: "File not found"])
        }
        return try fs_decoder.decode(Self.self, from: Data(contentsOf: url))
    }

    // MARK: - Create

    @discardableResult
    static func fs_create(_ entity: Self) throws -> Self {
        let url = fileURL(for: entity.id)
        guard !FileManager.default.fileExists(atPath: url.path) else {
            throw NSError(domain: "FileSystemResource", code: 409, userInfo: [NSLocalizedDescriptionKey: "File already exists"])
        }
        try fs_encoder.encode(entity).write(to: url)
        return entity
    }

    @discardableResult
    static func fs_createMany(_ entities: [Self]) throws -> [Self] {
        try entities.map { try fs_create($0) }
    }

    // MARK: - Update

    @discardableResult
    static func fs_update(_ entity: Self) throws -> Self {
        let url = fileURL(for: entity.id)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw NSError(domain: "FileSystemResource", code: 404, userInfo: [NSLocalizedDescriptionKey: "File not found"])
        }
        try fs_encoder.encode(entity).write(to: url)
        return entity
    }

    @discardableResult
    static func fs_updateMany(_ entities: [Self]) throws -> [Self] {
        try entities.map { try fs_update($0) }
    }

    // MARK: - Delete

    static func fs_delete(_ id: ID) throws {
        let url = fileURL(for: id)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw NSError(domain: "FileSystemResource", code: 404, userInfo: [NSLocalizedDescriptionKey: "File not found"])
        }
        try FileManager.default.removeItem(at: url)
    }

    static func fs_deleteMany(_ ids: [ID]) throws {
        for id in ids {
            try fs_delete(id)
        }
    }

    // MARK: - Instance Methods

    @discardableResult
    func fs_create() throws -> Self {
        try Self.fs_create(self)
    }

    @discardableResult
    func fs_update() throws -> Self {
        try Self.fs_update(self)
    }

    func fs_delete() throws {
        try Self.fs_delete(self.id)
    }
}

// MARK: - Product + FileSystemResource

extension Product: FileSystemResource {}
