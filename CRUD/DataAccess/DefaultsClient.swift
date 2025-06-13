import Foundation
import os.log

// MARK: - DefaultsService

private let logger = Logger(subsystem: "io.mobiledge.CRUD", category: "Defaults")

struct DefaultsService {
    let defaults: UserDefaults

    func fetch(key: String) -> Data? {
        guard let data = defaults.data(forKey: key) else {
            logger.debug("No data found for key '\(key)'")
            return nil
        }
        logger.debug("Fetched data for key '\(key)'")
        return data
    }

    func save(key: String, value: Data) {
        defaults.set(value, forKey: key)
        logger.info("Saved value for key '\(key)'")
    }

    func remove(key: String) {
        defaults.removeObject(forKey: key)
        logger.info("Removed value for key '\(key)'")
    }
}

struct DefaultsClient<T: Codable & Identifiable> {
    let service: DefaultsService
    let encoder: JSONEncoder
    let decoder: JSONDecoder

    private var key: String {
        String(describing: T.self)
    }

    func fetch() -> T? {
        guard let data = service.fetch(key: key) else {
            return nil
        }
        do {
            let entity = try decoder.decode(T.self, from: data)
            return entity
        } catch {
            logger.error("Failed to decode type '\(self.key)' from UserDefaults. Error: \(error.localizedDescription)")
            return nil
        }
    }

    func save(_ entity: T) {
        do {
            let data = try encoder.encode(entity)
            service.save(key: key, value: data)
        } catch {
            logger.error("Failed to encode type '\(self.key)' for UserDefaults. Error: \(error.localizedDescription)")
        }
    }

    func remove() {
        service.remove(key: key)
    }
}
