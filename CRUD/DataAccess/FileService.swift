import Foundation
import os.log

private let logger = Logger(subsystem: "io.mobiledge.CRUD", category: "FileService")

// MARK: - FileService (Unchanged)

/// A service that provides the fundamental behaviors for file storage.
/// This struct acts as a "witness" by holding closures for its core operations,
/// allowing the underlying storage mechanism (file system, in-memory, etc.)
/// to be swapped out for testing or different contexts.
struct FileService {
    var fetch: (_ filename: String) -> Data?
    var save: (_ filename: String, _ data: Data) -> Void
    var remove: (_ filename: String) -> Void
}

extension FileService {
    /// The default service instance, configured to use the app's document directory.
    static let `default` = FileService(
        fetch: { filename in
            guard let url = url(for: filename) else { return nil }
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            do {
                return try Data(contentsOf: url)
            } catch {
                logger.error("Failed to read data from file '\(filename)': \(error.localizedDescription)")
                return nil
            }
        },
        save: { filename, data in
            guard let url = url(for: filename) else { return }
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                logger.error("Failed to save data to file '\(filename)': \(error.localizedDescription)")
            }
        },
        remove: { filename in
            guard let url = url(for: filename) else { return }
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                logger.error("Failed to remove file '\(filename)': \(error.localizedDescription)")
            }
        }
    )
    
    /// A private helper to get the URL for a file in the document directory.
    private static func url(for filename: String) -> URL? {
        guard let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            logger.error("Could not access document directory.")
            return nil
        }
        return docDir.appendingPathComponent(filename)
    }

    /// A mock service that uses an in-memory dictionary for storage.
    /// Perfect for SwiftUI previews or unit tests.
    static func mock(initialFiles: [String: Data] = [:]) -> FileService {
        var store = initialFiles
        return FileService(
            fetch: { filename in store[filename] },
            save: { filename, data in store[filename] = data },
            remove: { filename in store[filename] = nil }
        )
    }
}


// MARK: - FileClient

/// A client for CRUD operations on a collection of `Codable & Identifiable` objects
/// within a single file, specifically using the JSON format.
struct FileClient<T: Codable & Identifiable> {
    let service: FileService
    let filename: String

    let encoder: JSONEncoder
    let decoder: JSONDecoder
    
    init(
        service: FileService = .default,
        filename: String,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.service = service
        self.filename = filename
        self.encoder = encoder
        self.decoder = decoder
    }

    // MARK: - Read Operations
    
    /// Fetches the entire collection from the file.
    /// - Returns: An array of decoded items, or an empty array if the file doesn't exist or fails to decode.
    func all() -> [T] {
        guard let data = service.fetch(filename) else { return [] }
        do {
            return try self.decoder.decode([T].self, from: data)
        } catch {
            logger.error("Failed to decode '\(self.filename)': \(error.localizedDescription)")
            return []
        }
    }
    
    /// Returns all items in the collection that satisfy the given predicate.
    /// - Parameter predicate: A closure that takes an item as its argument and returns a Boolean value indicating whether the item should be included in the returned array.
    /// - Returns: An array of the items that satisfy the predicate.
    func all(where predicate: (T) -> Bool) -> [T] {
        return all().filter(predicate)
    }
    
    /// Finds the first item in the collection with the specified ID.
    /// - Parameter id: The unique identifier of the item to find.
    /// - Returns: The first item that matches the ID, or `nil` if no match is found.
    func find(id: T.ID) -> T? {
        return all().first { $0.id == id }
    }
    
    /// Finds the first item in the collection that satisfies the given predicate.
    /// - Parameter predicate: A closure that returns a Boolean value.
    /// - Returns: The first item in the collection that satisfies the `predicate`, or `nil` if no such item is found.
    func find(where predicate: (T) -> Bool) -> T? {
        return all().first(where: predicate)
    }
    
    // MARK: - Write Operations
    
    /// Saves (inserts or updates) a single item in the collection.
    /// This is a "read-modify-write" operation.
    /// - Parameter entity: The item to save.
    func save(_ entity: T) {
        var items = all()
        if let index = items.firstIndex(where: { $0.id == entity.id }) {
            items[index] = entity
        } else {
            items.append(entity)
        }
        replaceAll(with: items)
    }
    
    /// Efficiently saves (inserts or updates) multiple items in the collection.
    /// This performs only one file read and one file write for the entire operation.
    /// - Parameter entities: The array of items to save.
    func saveMany(upserting entities: [T]) {
        guard !entities.isEmpty else { return }
        let items = all()
        var itemDict = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        
        for entity in entities {
            itemDict[entity.id] = entity
        }
        
        replaceAll(with: Array(itemDict.values))
    }
    
    /// Replaces the entire collection in the file with a new array of items.
    /// - Parameter entities: The new array of items to persist.
    func replaceAll(with entities: [T]) {
        do {
            let data = try self.encoder.encode(entities)
            service.save(filename, data)
        } catch {
            logger.error("Failed to encode '\(self.filename)': \(error.localizedDescription)")
        }
    }

    // MARK: - Delete Operations
    
    /// Deletes a single item from the collection.
    /// - Parameter entity: The item to delete.
    func delete(_ entity: T) {
        var items = all()
        items.removeAll { $0.id == entity.id }
        replaceAll(with: items)
    }
    
    /// Efficiently deletes multiple items from the collection.
    /// This performs only one file read and one file write for the entire operation.
    /// - Parameter entities: The array of items to delete.
    func delete(subset entities: [T]) {
        guard !entities.isEmpty else { return }
        var items = all()
        let idsToDelete = Set(entities.map { $0.id })
        items.removeAll { idsToDelete.contains($0.id) }
        replaceAll(with: items)
    }

    /// Deletes the file, thereby removing the entire collection.
    func deleteAll() {
        service.remove(filename)
    }
}
