import XCTest
@testable import CRUD

@MainActor
class ProductListViewModelTests: XCTestCase {
    
    enum TestError: Error, LocalizedError, Equatable {
        case genericError
        var errorDescription: String? { "A test error occurred" }
    }

    var mockNetworkService: MockProductNetworkService!
    var productRepository: ProductRepository!
    var viewModel: ProductListViewModel!

    override func setUpWithError() throws {
        try super.setUpWithError()
        mockNetworkService = MockProductNetworkService()
        productRepository = ProductRepository(productNetworkService: mockNetworkService)
        viewModel = ProductListViewModel(repository: productRepository)
    }

    override func tearDownWithError() throws {
        viewModel = nil
        productRepository = nil
        mockNetworkService = nil
        try super.tearDownWithError()
    }

    
    func testInitialization() {
        XCTAssertFalse(viewModel.isLoading, "ViewModel should not be loading initially.")
        XCTAssertNil(viewModel.error, "ViewModel error should be nil initially.")
        XCTAssertTrue(viewModel.products.isEmpty, "ViewModel products should be empty initially.")
        XCTAssertNotNil(viewModel.repository, "ViewModel repository should be initialized.")
    }
    
    func testFetchProducts_Success() async {
        
        // Arrange
        mockNetworkService.fetchAllHandler = {
            try await Task.sleep(for: .seconds(2))
            return Product.mockArray
        }
        
        // Check state before fetch
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        XCTAssertTrue(viewModel.products.isEmpty)

        // Act
        let task = Task {
            await viewModel.fetchProducts()
        }
        
        try? await Task.sleep(for: .seconds(1))
        
        // Check state during fetch
        XCTAssertTrue(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        XCTAssertTrue(viewModel.products.isEmpty)

        await task.value // Wait for the fetchProducts task to complete

        // Check state after fetch complete
        XCTAssertFalse(viewModel.isLoading, "ViewModel should not be loading after successful fetch.")
        XCTAssertNil(viewModel.error, "ViewModel error should be nil after successful fetch.")
        XCTAssertEqual(viewModel.products, Product.mockArray, "ViewModel products should match fetched products.")
    }
    
    func testFetchProducts_Failure2() async {
        
        // Arrange
        mockNetworkService.fetchAllHandler = {
            try await Task.sleep(for: .seconds(2))
            throw TestError.genericError
        }
        
        // Check state before fetch
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        XCTAssertTrue(viewModel.products.isEmpty)

        // Act
        let task = Task {
            await viewModel.fetchProducts()
        }
        
        try? await Task.sleep(for: .seconds(1))
        
        // Check state during fetch
        XCTAssertTrue(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        XCTAssertTrue(viewModel.products.isEmpty)

        await task.value // Wait for the fetchProducts task to complete

        // Check state after fetch complete
        XCTAssertFalse(viewModel.isLoading, "ViewModel should not be loading after successful fetch.")
        XCTAssertNotNil(viewModel.error, "ViewModel error should be nil after successful fetch.")
        XCTAssertTrue(viewModel.products.isEmpty)
        
        if let receivedError = viewModel.error as? TestError {
            XCTAssertEqual(receivedError, TestError.genericError, "ViewModel error should be the one thrown by the service.")
        } else {
            XCTFail("ViewModel error is not of the expected type TestError. Received: \(String(describing: viewModel.error))")
        }
    }
}
