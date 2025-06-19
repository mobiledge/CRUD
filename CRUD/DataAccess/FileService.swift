import Foundation
import os.log

private let logger = Logger(subsystem: "io.mobiledge.CRUD", category: "FileService")

// MARK: - Core Service

/// A service that provides the fundamental behaviors for file storage.
struct FileService {
    var fetch: (_ filename: String) -> Result<Data, Error>
    var save: (_ filename: String, _ data: Data) -> Result<Void, Error>
    var remove: (_ filename: String) -> Void
}

extension FileService {
    /// A custom error type for file service operations.
    enum FileError: Error {
        case fileNotFound
        case readFailed(Error)
        case writeFailed(Error)
        case directoryUnavailable
    }
    
    /// The default service instance, configured to use the app's document directory.
    static let `default` = FileService(
        fetch: { filename in
            guard let url = url(for: filename) else { return .failure(FileError.directoryUnavailable) }
            guard FileManager.default.fileExists(atPath: url.path) else { return .failure(FileError.fileNotFound) }
            do {
                return .success(try Data(contentsOf: url))
            } catch {
                logger.error("Failed to read data from file '\(filename)': \(error.localizedDescription)")
                return .failure(FileError.readFailed(error))
            }
        },
        save: { filename, data in
            guard let url = url(for: filename) else { return .failure(FileError.directoryUnavailable) }
            do {
                try data.write(to: url, options: .atomic)
                return .success(())
            } catch {
                logger.error("Failed to save data to file '\(filename)': \(error.localizedDescription)")
                return .failure(FileError.writeFailed(error))
            }
        },
        remove: { filename in
            guard let url = url(for: filename), FileManager.default.fileExists(atPath: url.path) else { return }
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                logger.error("Failed to remove file '\(filename)': \(error.localizedDescription)")
            }
        }
    )
    
    private static func url(for filename: String) -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(filename)
    }
    
    /// A mock service that uses an in-memory dictionary for storage.
    static func mock(initialFiles: [String: Data] = [:]) -> FileService {
        var store = initialFiles
        return FileService(
            fetch: { filename in store[filename].map { .success($0) } ?? .failure(FileError.fileNotFound) },
            save: { filename, data in store[filename] = data; return .success(()) },
            remove: { filename in store[filename] = nil }
        )
    }
}


// MARK: - Approach 1: Protocol-Oriented Resource
/**
 Trade-offs:
 Offers a clean, declarative API that works on a single service instance. It provides better error handling
 and type safety by linking the model to its storage properties. Its main requirement is for the model type itself to conform to the protocol.
 
 Usage Example:
 struct Task: Codable, Identifiable, FileCollectionResource {
 let id: UUID
 var title: String
 }
 let service = FileService.default
 let tasksToSave = [Task(id: .init(), title: "First"), Task(id: .init(), title: "Second")]
 _ = service.saveMany(upserting: tasksToSave, to: Task.self)
 */
protocol FileCollectionResource {
    static var filename: String { get }
    static func encode(items: [Self]) -> Result<Data, Error>
    static func decode(from data: Data) -> Result<[Self], Error>
}

extension FileCollectionResource where Self: Codable {
    static var filename: String { "\(String(describing: Self.self).lowercased())s.json" }
    static func encode(items: [Self]) -> Result<Data, Error> { Result { try JSONEncoder().encode(items) } }
    static func decode(from data: Data) -> Result<[Self], Error> { Result { try JSONDecoder().decode([Self].self, from: data) } }
}

extension FileService {
    // MARK: Read Operations
    func all<T: FileCollectionResource>(for resource: T.Type) -> Result<[T], Error> {
        switch fetch(T.filename) {
        case .success(let data):
            // If the file is found, proceed with decoding.
            return T.decode(from: data)
        case .failure(let error):
            // If the error is `fileNotFound`, it's not a true failure for `all()`.
            // It simply means the collection is empty.
            if case FileError.fileNotFound = error {
                return .success([])
            }
            // For all other errors, propagate the failure.
            return .failure(error)
        }
    }
    
    func all<T: FileCollectionResource>(for resource: T.Type, where predicate: (T) -> Bool) -> Result<[T], Error> {
        all(for: resource).map { $0.filter(predicate) }
    }
    
    func find<T: FileCollectionResource & Identifiable>(id: T.ID, in resource: T.Type) -> Result<T?, Error> {
        all(for: resource).map { items in items.first { $0.id == id } }
    }
    
    func find<T: FileCollectionResource>(where predicate: (T) -> Bool, in resource: T.Type) -> Result<T?, Error> {
        all(for: resource).map { items in items.first(where: predicate) }
    }
    
    // MARK: Write Operations
    func replaceAll<T: FileCollectionResource>(with items: [T], for resource: T.Type) -> Result<Void, Error> {
        T.encode(items: items).flatMap { data in save(T.filename, data) }
    }
    
    func save<T: FileCollectionResource & Identifiable>(_ item: T, to resource: T.Type) -> Result<Void, Error> {
        all(for: resource).flatMap { currentItems in
            var items = currentItems
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index] = item
            } else {
                items.append(item)
            }
            return replaceAll(with: items, for: resource)
        }
    }
    
    func saveMany<T: FileCollectionResource & Identifiable>(upserting itemsToSave: [T], to resource: T.Type) -> Result<Void, Error> {
        guard !itemsToSave.isEmpty else { return .success(()) }
        return all(for: resource).flatMap { currentItems in
            var itemDict = Dictionary(uniqueKeysWithValues: currentItems.map { ($0.id, $0) })
            for item in itemsToSave {
                itemDict[item.id] = item
            }
            return replaceAll(with: Array(itemDict.values), for: resource)
        }
    }
    
    // MARK: Delete Operations
    func delete<T: FileCollectionResource & Identifiable>(_ item: T, from resource: T.Type) -> Result<Void, Error> {
        all(for: resource).flatMap { currentItems in
            var items = currentItems
            items.removeAll { $0.id == item.id }
            return replaceAll(with: items, for: resource)
        }
    }
    
    func delete<T: FileCollectionResource & Identifiable>(subset itemsToDelete: [T], from resource: T.Type) -> Result<Void, Error> {
        guard !itemsToDelete.isEmpty else { return .success(()) }
        return all(for: resource).flatMap { currentItems in
            var items = currentItems
            let idsToDelete = Set(itemsToDelete.map { $0.id })
            items.removeAll { idsToDelete.contains($0.id) }
            return replaceAll(with: items, for: resource)
        }
    }
    
    func deleteAll<T: FileCollectionResource>(for resource: T.Type) {
        remove(T.filename)
    }
}


// MARK: - Approach 2: Configured Client

/**
 Trade-offs:
 Self-contained and bundles all logic for a collection into one object. However, it swallows errors,
 provides weaker error handling, and requires instantiating and managing a client object for each collection.

 Usage Example:
 struct Task: Codable, Identifiable { let id: UUID; var title: String }
 
 let taskClient = FileClient<Task>(filename: "all_tasks.json")
 let tasksToSave = [Task(id: .init(), title: "First"), Task(id: .init(), title: "Second")]
 
 // Save multiple items
 taskClient.saveMany(upserting: tasksToSave)
 
 // Get all items
 let tasks = taskClient.all()
 print("Found \(tasks.count) tasks.") // Found 2 tasks.
 */
struct FileClient<T: Identifiable> {
    let service: FileService
    let filename: String
    let encode: ([T]) -> Result<Data, Error>
    let decode: (Data) -> Result<[T], Error>
    
    init(
        service: FileService = .default,
        filename: String,
        encode: @escaping ([T]) -> Result<Data, Error>,
        decode: @escaping (Data) -> Result<[T], Error>
    ) {
        self.service = service
        self.filename = filename
        self.encode = encode
        self.decode = decode
    }
    
    // MARK: Read Operations
    func all() -> [T] {
        guard case .success(let data) = service.fetch(filename) else { return [] }
        switch decode(data) {
        case .success(let items): return items
        case .failure(let error):
            logger.error("Failed to decode '\(self.filename)': \(error.localizedDescription)")
            return []
        }
    }
    
    func all(where predicate: (T) -> Bool) -> [T] {
        all().filter(predicate)
    }
    
    func find(id: T.ID) -> T? {
        all().first { $0.id == id }
    }
    
    func find(where predicate: (T) -> Bool) -> T? {
        all().first(where: predicate)
    }
    
    // MARK: Write Operations
    func save(_ entity: T) {
        var items = all()
        if let index = items.firstIndex(where: { $0.id == entity.id }) {
            items[index] = entity
        } else {
            items.append(entity)
        }
        replaceAll(with: items)
    }
    
    func saveMany(upserting entities: [T]) {
        guard !entities.isEmpty else { return }
        let items = all()
        var itemDict = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        for entity in entities {
            itemDict[entity.id] = entity
        }
        replaceAll(with: Array(itemDict.values))
    }
    
    func replaceAll(with entities: [T]) {
        switch encode(entities) {
        case .success(let data):
            _ = service.save(filename, data)
        case .failure(let error):
            logger.error("Failed to encode '\(self.filename)': \(error.localizedDescription)")
        }
    }
    
    // MARK: Delete Operations
    func delete(_ entity: T) {
        var items = all()
        items.removeAll { $0.id == entity.id }
        replaceAll(with: items)
    }
    
    func delete(subset entities: [T]) {
        guard !entities.isEmpty else { return }
        var items = all()
        let idsToDelete = Set(entities.map { $0.id })
        items.removeAll { idsToDelete.contains($0.id) }
        replaceAll(with: items)
    }
    
    func deleteAll() {
        service.remove(filename)
    }
}

extension FileClient where T: Codable {
    /// Convenience initializer for `Codable` types that use JSON.
    init(
        service: FileService = .default,
        filename: String
    ) {
        self.service = service
        self.filename = filename
        self.encode = { items in Result { try JSONEncoder().encode(items) } }
        self.decode = { data in Result { try JSONDecoder().decode([T].self, from: data) } }
    }
}
