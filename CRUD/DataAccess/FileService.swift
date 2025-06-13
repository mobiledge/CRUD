import Foundation
import os.log

private let logger = Logger(subsystem: "io.mobiledge.CRUD", category: "FileService")

// MARK: - FileService

struct FileService {
    
    let manager: FileManager = .default
    let directory: FileManager.SearchPathDirectory = .documentDirectory
    
    private func fileURL(for filename: String) -> URL? {
        guard let url = manager.urls(for: directory, in: .userDomainMask).first else {
            logger.error("Could not access document directory.")
            return nil
        }
        return url.appendingPathComponent(filename)
    }

    func fetch(filename: String) -> Data? {
        guard let url = fileURL(for: filename) else { return nil }
        
        guard manager.fileExists(atPath: url.path) else {
            logger.info("File '\(filename)' not found at path: \(url.path)")
            return nil
        }
        
        do {
            return try Data(contentsOf: url)
        } catch {
            logger.error("Failed to read data from file '\(filename)': \(error.localizedDescription)")
            return nil
        }
    }

    func save(filename: String, value: Data) {
        guard let url = fileURL(for: filename) else { return }
        
        do {
            try value.write(to: url, options: .atomic)
        } catch {
            logger.error("Failed to save data to file '\(filename)': \(error.localizedDescription)")
        }
    }

    func remove(filename: String) {
        guard let url = fileURL(for: filename) else { return }
        
        guard manager.fileExists(atPath: url.path) else {
            logger.info("Attempted to remove non-existent file: '\(filename)'")
            return
        }
        
        do {
            try manager.removeItem(at: url)
        } catch {
            logger.error("Failed to remove file '\(filename)': \(error.localizedDescription)")
        }
    }
}

// MARK: - FileClient

struct FileClient<T: Codable & Identifiable> {
    
    let service: FileService
    let filename: String
    let encoder: JSONEncoder
    let decoder: JSONDecoder
    
    /// Private Helpers
    
    private func fetchAllItems() -> [T] {
        guard let data = service.fetch(filename: filename) else { return [] }
        
        do {
            return try decoder.decode([T].self, from: data)
        } catch {
            logger.error("Failed to decode items from '\(filename)': \(error.localizedDescription)")
            return []
        }
    }
    
    private func saveAllItems(_ items: [T]) {
        do {
            let data = try encoder.encode(items)
            service.save(filename: filename, value: data)
        } catch {
            logger.error("Failed to encode items for '\(filename)': \(error.localizedDescription)")
        }
    }
    
    /// Read Operations
    
    func all() -> [T] {
        return fetchAllItems()
    }
    
    func all(where predicate: (T) -> Bool) -> [T] {
        return fetchAllItems().filter(predicate)
    }
    
    func find(id: T.ID) -> T? {
        return fetchAllItems().first { $0.id == id }
    }
    
    func find(where predicate: (T) -> Bool) -> T? {
        return fetchAllItems().first(where: predicate)
    }
    
    /// Write Operations
    
    func save(_ entity: T) {
        var items = fetchAllItems()
        if let index = items.firstIndex(where: { $0.id == entity.id }) {
            items[index] = entity
        } else {
            items.append(entity)
        }
        saveAllItems(items)
    }
    
    func saveMany(upserting entities: [T]) {
        let items = fetchAllItems()
        let itemsDict = Dictionary(grouping: items, by: { $0.id })
        var finalItems = itemsDict.mapValues { $0[0] }

        for entity in entities {
            finalItems[entity.id] = entity
        }

        saveAllItems(Array(finalItems.values))
    }
    
    func replaceAll(with entities: [T]) {
        saveAllItems(entities)
    }
    
    /// Delete Operations
    
    func delete(_ entity: T) {
        var items = fetchAllItems()
        items.removeAll { $0.id == entity.id }
        saveAllItems(items)
    }
    
    func delete(subset entities: [T]) {
        var items = fetchAllItems()
        let idsToDelete = Set(entities.map { $0.id })
        items.removeAll { idsToDelete.contains($0.id) }
        saveAllItems(items)
    }
    
    func deleteAll() {
        service.remove(filename: filename)
    }
}
