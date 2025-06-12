@testable import CRUD
import Foundation
import XCTest

final class FileSystemResourceTests: XCTestCase {

    override func setUpWithError() throws {
        // Clean up before each test
        let dir = Product.fs_directory
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    func testCreateAndFetchById() throws {
        let product = Product(id: 1, name: "Pen", description: "Blue ink", price: "1.00")
        try product.fs_create()

        let fetched = try Product.fs_fetchById(1)
        XCTAssertEqual(fetched, product)
    }

    func testUpdate() throws {
        var product = Product(id: 2, name: "Notebook", description: nil, price: "2.00")
        try product.fs_create()

        product.name = "Ruled Notebook"
        let updated = try product.fs_update()

        let fetched = try Product.fs_fetchById(2)
        XCTAssertEqual(updated.name, "Ruled Notebook")
        XCTAssertEqual(fetched.name, "Ruled Notebook")
    }

    func testDelete() throws {
        let product = Product(id: 3, name: "Marker", description: nil, price: "1.50")
        try product.fs_create()

        try product.fs_delete()

        XCTAssertThrowsError(try Product.fs_fetchById(3))
    }

    func testCreateManyAndFetchAll() throws {
        let items = [
            Product(id: 10, name: "Pencil", description: nil, price: "0.50"),
            Product(id: 11, name: "Eraser", description: nil, price: "0.20")
        ]
        try Product.fs_createMany(items)

        let all = try Product.fs_fetchAll()
        XCTAssertEqual(all.count, 2)
        XCTAssertTrue(all.contains(where: { $0.id == 10 }))
        XCTAssertTrue(all.contains(where: { $0.id == 11 }))
    }

    func testDeleteMany() throws {
        let items = [
            Product(id: 20, name: "Sharpener", description: nil, price: "0.80"),
            Product(id: 21, name: "Ruler", description: nil, price: "1.20")
        ]
        try Product.fs_createMany(items)
        try Product.fs_deleteMany([20, 21])

        XCTAssertThrowsError(try Product.fs_fetchById(20))
        XCTAssertThrowsError(try Product.fs_fetchById(21))
    }
}
