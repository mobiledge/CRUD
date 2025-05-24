import XCTest
@testable import CRUD

class ProductServiceTests: XCTestCase {

    var mockServer: HTTPServer!

    override func setUp() {
        super.setUp()
        mockServer = .mock
    }

    override func tearDown() {
        mockServer = nil
        super.tearDown()
    }

    func testFetchAll_Success() async throws {
        let expectedProducts = Product.mockProducts
        let productsData = try JSONEncoder().encode(expectedProducts)
        let mockSession = HTTPSession.mockSuccess(data: productsData)
        let productService = ProductService.live(server: mockServer, session: mockSession)
        let fetchedProducts = try await productService.fetchAll()
        XCTAssertEqual(fetchedProducts.count, expectedProducts.count)
    }

    func testFetchAll_Failure_BadStatusCode() async {
        let expectedError = HTTPError.badStatusCode(500)
        let mockSession = HTTPSession.mockError(expectedError)
        let productService = ProductService.live(server: mockServer, session: mockSession)

        do {
            _ = try await productService.fetchAll()
            XCTFail("fetchAll should have thrown an error.")
        } catch let error as HTTPError {
            guard case .badStatusCode(let statusCode) = error else {
                XCTFail("Incorrect HTTPError type: \(error)")
                return
            }
            XCTAssertEqual(statusCode, 500)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testFetchById_Success() async throws {
        let expectedProduct = Product.mock
        let productData = try JSONEncoder().encode(expectedProduct)
        let mockSession = HTTPSession.mockSuccess(data: productData)
        let productService = ProductService.live(server: mockServer, session: mockSession)
        let fetchedProduct = try await productService.fetchById(expectedProduct.id)
        XCTAssertEqual(fetchedProduct.id, expectedProduct.id)
        XCTAssertEqual(fetchedProduct.name, expectedProduct.name)
    }
}
