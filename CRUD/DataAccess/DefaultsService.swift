import Foundation
import os.log
import UIKit // Imported for the non-Codable UIImage example

private let logger = Logger(subsystem: "io.mobiledge.CRUD", category: "DefaultsService")

// MARK: - Core Service

/// A service that provides the fundamental behaviors for a key-value store.
/// This abstraction allows for easy testing and swapping the underlying storage mechanism.
struct DefaultsService {
    var fetch: (_ key: String) -> Data?
    var save: (_ key: String, _ value: Data) -> Void
    var remove: (_ key: String) -> Void
}

extension DefaultsService {
    /// The default service, backed by `UserDefaults.standard`.
    static let `default` = DefaultsService(
        fetch: { key in UserDefaults.standard.data(forKey: key) },
        save: { key, value in UserDefaults.standard.set(value, forKey: key) },
        remove: { key in UserDefaults.standard.removeObject(forKey: key) }
    )

    /// A mock service, backed by an in-memory dictionary, for use in previews and unit tests.
    static func mock(initialValues: [String: Data] = [:]) -> DefaultsService {
        var store = initialValues
        return DefaultsService(
            fetch: { key in store[key] },
            save: { key, value in store[key] = value },
            remove: { key in store[key] = nil }
        )
    }
}

// MARK: - Approach 1: Protocol-Oriented Resource

// Trade-offs: Superior for most applications. It offers robust error handling, high flexibility for non-Codable types,
// and excellent type safety. Its primary requirement is that models must conform to the `DefaultsResource` protocol.
/*
 // Usage Example:
 struct UserPreferences: Codable { let theme: String }
 extension UserPreferences: DefaultsResource {} // Conformance is often a single line.
 
 let service = DefaultsService.default
 let newPrefs = UserPreferences(theme: "dark")

 // Save an instance
 if case .failure(let error) = service.save(newPrefs) { print("Save failed: \(error)") }
 
 // Fetch by type
 switch service.fetch(UserPreferences.self) {
 case .success(let savedPrefs): print(savedPrefs?.theme ?? "no theme set")
 case .failure(let error): print("Fetch failed: \(error)")
 }
 
 // Remove by type
 service.remove(UserPreferences.self)
*/
protocol DefaultsResource {
    static var defaultsKey: String { get }
    func encode() -> Result<Data, Error>
    static func decode(from data: Data) -> Result<Self, Error>
}

extension DefaultsResource where Self: Codable {
    static var defaultsKey: String { String(describing: self).lowercased() }
    func encode() -> Result<Data, Error> { Result { try JSONEncoder().encode(self) } }
    static func decode(from data: Data) -> Result<Self, Error> { Result { try JSONDecoder().decode(Self.self, from: data) } }
}

extension DefaultsService {
    func fetch<T: DefaultsResource>(_ resourceType: T.Type) -> Result<T?, Error> {
        let key = resourceType.defaultsKey
        guard let data = fetch(key) else { return .success(nil) }
        return resourceType.decode(from: data).map { Optional($0) }
    }
    
    func save<T: DefaultsResource>(_ value: T) -> Result<Void, Error> {
        value.encode().map { data in save(T.defaultsKey, data) }
    }

    func remove<T: DefaultsResource>(_ resourceType: T.Type) {
        remove(resourceType.defaultsKey)
    }
}


// MARK: - Approach 2: Configured Client (Updated)

// Trade-offs: Now flexible enough to handle any data type via closures. However, it still has weaker error
// handling (swallowing errors into `nil` or logs) and requires instantiating and managing a client object for each task.
/*
 // Usage Example 1: Storing a Codable type (easy)
 struct UserPreferences: Codable { let theme: String }
 let prefsClient = DefaultsClient<UserPreferences>(key: "user_prefs_v1") // Uses convenience init
 prefsClient.save(UserPreferences(theme: "dark"))
 let theme = prefsClient.fetch()?.theme ?? "default"

 // Usage Example 2: Storing a non-Codable type like UIImage
 enum ImageError: Error { case conversionFailed }
 let avatarClient = DefaultsClient<UIImage>(
     key: "user_avatar",
     encode: { image in
         guard let data = image.pngData() else { return .failure(ImageError.conversionFailed) }
         return .success(data)
     },
     decode: { data in
         guard let image = UIImage(data: data) else { return .failure(ImageError.conversionFailed) }
         return .success(image)
     }
 )
 // let avatarImage: UIImage = ...
 // avatarClient.save(avatarImage)
*/
struct DefaultsClient<T> {
    let service: DefaultsService
    let key: String
    let encode: (T) -> Result<Data, Error>
    let decode: (Data) -> Result<T, Error>

    init(
        service: DefaultsService = .default,
        key: String,
        encode: @escaping (T) -> Result<Data, Error>,
        decode: @escaping (Data) -> Result<T, Error>
    ) {
        self.service = service
        self.key = key
        self.encode = encode
        self.decode = decode
    }

    func fetch() -> T? {
        guard let data = service.fetch(key) else { return nil }
        switch decode(data) {
        case .success(let value):
            return value
        case .failure(let error):
            logger.error("Failed to decode '\(self.key)': \(error.localizedDescription)")
            return nil
        }
    }

    func save(_ entity: T) {
        switch encode(entity) {
        case .success(let data):
            service.save(key, data)
        case .failure(let error):
            logger.error("Failed to encode '\(self.key)': \(error.localizedDescription)")
        }
    }

    func remove() {
        service.remove(key)
    }
}

extension DefaultsClient where T: Codable {
    /// Convenience initializer for `Codable` types.
    init(
        service: DefaultsService = .default,
        key: String = String(describing: T.self)
    ) {
        self.service = service
        self.key = key
        self.encode = { value in Result { try JSONEncoder().encode(value) } }
        self.decode = { data in Result { try JSONDecoder().decode(T.self, from: data) } }
    }
}
