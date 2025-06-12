import XCTest
@testable import CRUD

final class UserDefaultsResourceTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Clear all test data before each test
        Product.ud_defaults.removeObject(forKey: Product.ud_key)
    }
    
    override func tearDown() {
        // Clean up after each test
        Product.ud_defaults.removeObject(forKey: Product.ud_key)
        super.tearDown()
    }
    
    func testCreateAndFetchAll() throws {
        let product = Product(id: 1, name: "Shoes", description: "Running shoes", price: "$59.99")
        let _ = try product.ud_create()
        
        let all = try Product.ud_fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.name, "Shoes")
    }
    
    func testFetchById() throws {
        let product = Product(id: 101, name: "Backpack", description: nil, price: "$39.99")
        let _ = try product.ud_create()
        
        let fetched = try Product.ud_fetchById(101)
        XCTAssertEqual(fetched.name, "Backpack")
        XCTAssertEqual(fetched.price, "$39.99")
    }
    
    func testUpdate() throws {
        var product = Product(id: 10, name: "T-shirt", description: "Cotton", price: "$9.99")
        let _ = try product.ud_create()
        
        product.name = "Updated T-shirt"
        product.price = "$7.99"
        let _ = try product.ud_update()
        
        let updated = try Product.ud_fetchById(10)
        XCTAssertEqual(updated.name, "Updated T-shirt")
        XCTAssertEqual(updated.price, "$7.99")
    }
    
    func testDelete() throws {
        let product = Product(id: 5, name: "Water Bottle", description: nil, price: "$12.00")
        let _ = try product.ud_create()
        
        try product.ud_delete()
        
        let all = try Product.ud_fetchAll()
        XCTAssertTrue(all.isEmpty)
    }
    
    func testDuplicateCreateThrows() {
        let product = Product(id: 77, name: "Mouse", description: nil, price: "$29.99")
        XCTAssertNoThrow(try product.ud_create())
        
        XCTAssertThrowsError(try product.ud_create()) { error in
            XCTAssertEqual((error as NSError).code, 409)
        }
    }
    
    func testFetchMissingThrows() {
        XCTAssertThrowsError(try Product.ud_fetchById(999)) { error in
            XCTAssertEqual((error as NSError).code, 404)
        }
    }
    
    func testUpdateMissingThrows() {
        let ghost = Product(id: 888, name: "Ghost Item", description: nil, price: nil)
        XCTAssertThrowsError(try ghost.ud_update()) { error in
            XCTAssertEqual((error as NSError).code, 404)
        }
    }
    
    func testDeleteMissingThrows() {
        let ghost = Product(id: 999, name: "Ghost Item", description: nil, price: nil)
        XCTAssertThrowsError(try ghost.ud_delete()) { error in
            XCTAssertEqual((error as NSError).code, 404)
        }
    }
}
