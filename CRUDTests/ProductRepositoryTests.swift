import XCTest
@testable import CRUD

enum TestError: Error, Equatable {
    case network(String)
    case general
}

@MainActor // Ensures test methods run on the main actor, aligning with ProductRepository
class ProductRepositoryTests: XCTestCase {

    // MARK: - Test Cases

    // MARK: fetchAll()

    func testFetchAll_Success_UpdatesProductsAndReturnsFetchedProducts() async throws {
        // Arrange
        let expectedProducts = [
            Product(id: 101, name: "Fetched Product A"),
            Product(id: 102, name: "Fetched Product B")
        ]
        var mockNetworkService = MockProductNetworkService()
        mockNetworkService.fetchAllHandler = { expectedProducts }
        
        let sut = ProductRepository(productNetworkService: mockNetworkService)
        XCTAssertTrue(sut.products.isEmpty, "Products should be initially empty")

        // Act
        // The Task.sleep(for: .seconds(2)) in fetchAll() will cause this test to take at least 2 seconds.
        let fetchedProducts = try await sut.fetchAll()

        // Assert
        XCTAssertEqual(fetchedProducts, expectedProducts, "Returned products should match expected products.")
        XCTAssertEqual(sut.products, expectedProducts, "Repository products should be updated with fetched products.")
    }

    func testFetchAll_Failure_ThrowsErrorAndProductsRemainUnchanged() async {
        // Arrange
        var mockNetworkService = MockProductNetworkService()
        let expectedError = TestError.network("FetchAll failed")
        mockNetworkService.fetchAllHandler = { throw expectedError }

        let sut = ProductRepository(productNetworkService: mockNetworkService)
        let initialProducts = sut.products // Should be empty

        // Act & Assert
        do {
            _ = try await sut.fetchAll()
            XCTFail("fetchAll should have thrown an error.")
        } catch {
            XCTAssertEqual(error as? TestError, expectedError, "The thrown error should be the expected network error.")
            XCTAssertEqual(sut.products, initialProducts, "Repository products should remain unchanged after an error.")
        }
    }

    // MARK: fetchById()

    func testFetchById_Success_ProductExistsInRepository_UpdatesProductAndReturnsIt() async throws {
        // Arrange
        let existingProduct = Product(id: 201, name: "Original Name")
        let updatedProductFromService = Product(id: 201, name: "Updated Name From Service")
        
        var mockNetworkService = MockProductNetworkService()
        mockNetworkService.fetchByIdHandler = { id in
            XCTAssertEqual(id, 201, "fetchById called with incorrect ID.")
            return updatedProductFromService
        }
        
        let sut = ProductRepository(productNetworkService: mockNetworkService)
        sut.products = [Product(id: 200, name: "Other Product"), existingProduct]

        // Act
        let fetchedProduct = try await sut.fetchById(201)

        // Assert
        XCTAssertEqual(fetchedProduct, updatedProductFromService, "Returned product should be the one from the service.")
        XCTAssertEqual(sut.products.count, 2, "Product count should remain the same.")
        if let productInRepo = sut.products.first(where: { $0.id == 201 }) {
            XCTAssertEqual(productInRepo, updatedProductFromService, "Product in repository should be updated.")
        } else {
            XCTFail("Product with ID 201 not found in repository after fetch.")
        }
    }

    func testFetchById_Success_ProductNotExistsInRepository_AppendsProductAndReturnsIt() async throws {
        // Arrange
        let newProductFromServer = Product(id: 202, name: "New Product")
        
        var mockNetworkService = MockProductNetworkService()
        mockNetworkService.fetchByIdHandler = { id in
            XCTAssertEqual(id, 202, "fetchById called with incorrect ID.")
            return newProductFromServer
        }
        
        let sut = ProductRepository(productNetworkService: mockNetworkService)
        sut.products = [Product(id: 200, name: "Existing Product")]

        // Act
        let fetchedProduct = try await sut.fetchById(202)

        // Assert
        XCTAssertEqual(fetchedProduct, newProductFromServer, "Returned product should be the new one from the service.")
        XCTAssertEqual(sut.products.count, 2, "Product count should increase by one.")
        XCTAssertTrue(sut.products.contains(newProductFromServer), "New product should be appended to repository products.")
    }

    func testFetchById_Failure_ThrowsErrorAndProductsRemainUnchanged() async {
        // Arrange
        var mockNetworkService = MockProductNetworkService()
        let expectedError = TestError.network("FetchById failed")
        mockNetworkService.fetchByIdHandler = { _ in throw expectedError }

        let sut = ProductRepository(productNetworkService: mockNetworkService)
        let initialProduct = Product(id: 1, name: "Initial")
        sut.products = [initialProduct]
        let initialProductsState = sut.products


        // Act & Assert
        do {
            _ = try await sut.fetchById(1)
            XCTFail("fetchById should have thrown an error.")
        } catch {
            XCTAssertEqual(error as? TestError, expectedError, "The thrown error should be the expected network error.")
            XCTAssertEqual(sut.products, initialProductsState, "Repository products should remain unchanged after an error.")
        }
    }

    // MARK: create()

    func testCreate_Success_AppendsProductToListAndReturnsIt() async throws {
        // Arrange
        let productToCreate = Product(id: 0, name: "New Product Pre-Create") // Assuming backend might assign ID
        let createdProductFromServer = Product(id: 301, name: "New Product Post-Create")
        
        var mockNetworkService = MockProductNetworkService()
        mockNetworkService.createHandler = { product in
            // You might want to assert productToCreate properties here if needed
            XCTAssertEqual(product.name, productToCreate.name)
            return createdProductFromServer
        }
        
        let sut = ProductRepository(productNetworkService: mockNetworkService)
        XCTAssertTrue(sut.products.isEmpty, "Products should be initially empty")

        // Act
        let resultProduct = try await sut.create(productToCreate)

        // Assert
        XCTAssertEqual(resultProduct, createdProductFromServer, "Returned product should be the one from the service.")
        XCTAssertEqual(sut.products.count, 1, "Product count should increase by one.")
        XCTAssertTrue(sut.products.contains(createdProductFromServer), "Created product should be appended to repository products.")
    }

    func testCreate_Failure_ThrowsErrorAndProductsRemainUnchanged() async {
        // Arrange
        let productToCreate = Product(id: 302, name: "Product To Create")
        var mockNetworkService = MockProductNetworkService()
        let expectedError = TestError.network("Create failed")
        mockNetworkService.createHandler = { _ in throw expectedError }

        let sut = ProductRepository(productNetworkService: mockNetworkService)
        let initialProductsState = sut.products

        // Act & Assert
        do {
            _ = try await sut.create(productToCreate)
            XCTFail("create should have thrown an error.")
        } catch {
            XCTAssertEqual(error as? TestError, expectedError, "The thrown error should be the expected network error.")
            XCTAssertEqual(sut.products, initialProductsState, "Repository products should remain unchanged after an error.")
        }
    }

    // MARK: update()

    func testUpdate_Success_ProductExists_UpdatesProductInListAndReturnsIt() async throws {
        // Arrange
        let originalProduct = Product(id: 401, name: "Original Name")
        let productToUpdateWith = Product(id: 401, name: "Updated Name") // This is passed to sut.update()
        let updatedProductFromServer = Product(id: 401, name: "Name From Server After Update") // Mock service returns this

        var mockNetworkService = MockProductNetworkService()
        mockNetworkService.updateHandler = { product in
            XCTAssertEqual(product, productToUpdateWith, "Product passed to service for update is incorrect.")
            return updatedProductFromServer
        }
        
        let sut = ProductRepository(productNetworkService: mockNetworkService)
        sut.products = [Product(id: 400, name: "Other"), originalProduct]

        // Act
        let resultProduct = try await sut.update(productToUpdateWith)

        // Assert
        XCTAssertEqual(resultProduct, updatedProductFromServer, "Returned product should be the one from the service.")
        XCTAssertEqual(sut.products.count, 2, "Product count should remain the same.")
        if let productInRepo = sut.products.first(where: { $0.id == 401 }) {
            XCTAssertEqual(productInRepo, updatedProductFromServer, "Product in repository should be updated to the version from server.")
        } else {
            XCTFail("Product with ID 401 not found in repository after update.")
        }
    }
    
    func testUpdate_Success_ProductNotExistsInRepository_ReturnsProductButListUnchanged() async throws {
        // Arrange
        let productNotInRepo = Product(id: 402, name: "Non Existent Product")
        let productFromServer = Product(id: 402, name: "Non Existent Product From Server")

        var mockNetworkService = MockProductNetworkService()
        mockNetworkService.updateHandler = { product in
            XCTAssertEqual(product, productNotInRepo)
            return productFromServer
        }
        
        let sut = ProductRepository(productNetworkService: mockNetworkService)
        sut.products = [Product(id: 400, name: "Some other product")]
        let initialProductsCount = sut.products.count

        // Act
        let resultProduct = try await sut.update(productNotInRepo)

        // Assert
        XCTAssertEqual(resultProduct, productFromServer, "Returned product should be from the service.")
        XCTAssertEqual(sut.products.count, initialProductsCount, "Product count should remain unchanged.")
        XCTAssertFalse(sut.products.contains(where: { $0.id == 402 }), "Product should not have been added to the list.")
    }

    func testUpdate_Failure_ThrowsErrorAndProductsRemainUnchanged() async {
        // Arrange
        let productToUpdate = Product(id: 403, name: "Product To Update")
        var mockNetworkService = MockProductNetworkService()
        let expectedError = TestError.network("Update failed")
        mockNetworkService.updateHandler = { _ in throw expectedError }

        let sut = ProductRepository(productNetworkService: mockNetworkService)
        sut.products = [productToUpdate]
        let initialProductsState = sut.products


        // Act & Assert
        do {
            _ = try await sut.update(productToUpdate)
            XCTFail("update should have thrown an error.")
        } catch {
            XCTAssertEqual(error as? TestError, expectedError, "The thrown error should be the expected network error.")
            XCTAssertEqual(sut.products, initialProductsState, "Repository products should remain unchanged after an error.")
        }
    }

    // MARK: delete()

    func testDelete_Success_ProductExists_RemovesProductFromList() async throws {
        // Arrange
        let productToDelete = Product(id: 501, name: "To Delete")
        let otherProduct = Product(id: 500, name: "To Keep")
        
        var mockNetworkService = MockProductNetworkService()
        mockNetworkService.deleteHandler = { id in
            XCTAssertEqual(id, 501, "delete called with incorrect ID.")
            // Default mock does nothing, which implies success
        }
        
        let sut = ProductRepository(productNetworkService: mockNetworkService)
        sut.products = [otherProduct, productToDelete]

        // Act
        try await sut.delete(501)

        // Assert
        XCTAssertEqual(sut.products.count, 1, "Product count should decrease by one.")
        XCTAssertFalse(sut.products.contains(productToDelete), "Deleted product should be removed from repository.")
        XCTAssertTrue(sut.products.contains(otherProduct), "Other product should remain in repository.")
    }
    
    func testDelete_Success_ProductNotExistsInRepository_ListRemainsUnchanged() async throws {
        // Arrange
        let otherProduct = Product(id: 500, name: "To Keep")
        let idToDelete = 502 // This ID is not in the list
        
        var mockNetworkService = MockProductNetworkService()
        mockNetworkService.deleteHandler = { id in
            XCTAssertEqual(id, idToDelete)
        }
        
        let sut = ProductRepository(productNetworkService: mockNetworkService)
        sut.products = [otherProduct]
        let initialProducts = sut.products

        // Act
        try await sut.delete(idToDelete)

        // Assert
        XCTAssertEqual(sut.products, initialProducts, "Product list should remain unchanged.")
    }

    func testDelete_Failure_ThrowsErrorAndProductsRemainUnchanged() async {
        // Arrange
        let productToDelete = Product(id: 503, name: "Product To Delete")
        var mockNetworkService = MockProductNetworkService()
        let expectedError = TestError.network("Delete failed")
        mockNetworkService.deleteHandler = { _ in throw expectedError }

        let sut = ProductRepository(productNetworkService: mockNetworkService)
        sut.products = [productToDelete]
        let initialProductsState = sut.products

        // Act & Assert
        do {
            try await sut.delete(productToDelete.id)
            XCTFail("delete should have thrown an error.")
        } catch {
            XCTAssertEqual(error as? TestError, expectedError, "The thrown error should be the expected network error.")
            XCTAssertEqual(sut.products, initialProductsState, "Repository products should remain unchanged after an error.")
        }
    }
}
