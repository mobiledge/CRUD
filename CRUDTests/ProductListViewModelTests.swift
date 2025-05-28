import XCTest
@testable import CRUD

@MainActor
class ProductListViewModelTests: XCTestCase {

    // MARK: - Test Specific Error
    private enum TestError: Error, LocalizedError, Equatable {
        case genericError
        var errorDescription: String? { "A specific test error occurred." }
    }

    // MARK: - Properties
    private var mockNetworkService: MockProductNetworkService!
    private var productRepository: ProductRepository!
    private var viewModel: ProductListViewModel!

    // MARK: - Setup & Teardown
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
        try super.tearDownWithError() // Call super last
    }

    // MARK: - Test Cases

    func testInitialization_ShouldHaveDefaultStates() {
        XCTAssertFalse(viewModel.isLoading, "ViewModel should not be loading upon initialization.")
        XCTAssertNil(viewModel.error, "ViewModel's error should be nil upon initialization.")
        XCTAssertTrue(viewModel.products.isEmpty, "ViewModel's products should be empty upon initialization.")
        XCTAssertNotNil(viewModel.repository, "ViewModel's repository should be initialized.")
    }

    func testFetchProducts_Success_UpdatesStateAndProducts() async throws {
        // Arrange
        let expectedProducts = Product.mockArray
        mockNetworkService.fetchAllHandler = {
            try await Task.sleep(for: .milliseconds(100)) // Simulate short network delay
            return expectedProducts
        }

        // Initial state assertions (optional here, but good for clarity)
        XCTAssertFalse(viewModel.isLoading, "Pre-condition: ViewModel should not be loading.")
        XCTAssertTrue(viewModel.products.isEmpty, "Pre-condition: Products should be empty.")
        XCTAssertNil(viewModel.error, "Pre-condition: Error should be nil.")

        // Act
        let fetchTask = Task {
            await viewModel.fetchProducts()
        }

        // Assert loading state immediately after calling fetch (or after a very brief moment)
        try await Task.sleep(for: .milliseconds(50)) // Allow state to update to isLoading = true
        if !Task.isCancelled { // Ensure task hasn't completed super fast
            XCTAssertTrue(viewModel.isLoading, "ViewModel should be loading while products are being fetched.")
            XCTAssertTrue(viewModel.products.isEmpty, "Products should remain empty while loading.")
            XCTAssertNil(viewModel.error, "Error should remain nil while loading on a success path.")
        }


        await fetchTask.value // Wait for the fetchProducts task to complete

        // Assert final state after successful fetch
        XCTAssertFalse(viewModel.isLoading, "ViewModel should not be loading after products are successfully fetched.")
        XCTAssertNil(viewModel.error, "ViewModel's error should be nil after a successful fetch.")
        XCTAssertEqual(viewModel.products, expectedProducts, "ViewModel's products should match the fetched products.")
    }

    func testFetchProducts_Failure_SetsErrorAndKeepsProductsEmpty() async throws {
        // Arrange
        let expectedError = TestError.genericError
        mockNetworkService.fetchAllHandler = {
            try await Task.sleep(for: .milliseconds(100)) // Simulate short network delay
            throw expectedError
        }

        // Initial state assertions
        XCTAssertFalse(viewModel.isLoading, "Pre-condition: ViewModel should not be loading.")
        XCTAssertTrue(viewModel.products.isEmpty, "Pre-condition: Products should be empty.")
        XCTAssertNil(viewModel.error, "Pre-condition: Error should be nil.")

        // Act
        let fetchTask = Task {
            await viewModel.fetchProducts()
        }

        // Assert loading state
        try await Task.sleep(for: .milliseconds(50))
         if !Task.isCancelled {
            XCTAssertTrue(viewModel.isLoading, "ViewModel should be loading when a fetch operation is in progress, even if it fails.")
            XCTAssertNil(viewModel.error, "Error should be nil before the fetch completes with an error.")
        }

        await fetchTask.value // Wait for the fetchProducts task to complete

        // Assert final state after failed fetch
        XCTAssertFalse(viewModel.isLoading, "ViewModel should not be loading after a fetch operation fails.")
        XCTAssertTrue(viewModel.products.isEmpty, "ViewModel's products should remain empty after a failed fetch.")
        XCTAssertNotNil(viewModel.error, "ViewModel's error should not be nil after a failed fetch.")

        let receivedError = try XCTUnwrap(viewModel.error as? TestError, "ViewModel error should be of type TestError. Received: \(String(describing: viewModel.error))")
        XCTAssertEqual(receivedError, expectedError, "ViewModel's error should be the one thrown by the network service.")
    }
}
