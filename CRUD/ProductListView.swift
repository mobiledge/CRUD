import SwiftUI

struct ProductListView: View {
    var viewModel: ProductListViewModel
    @State var isPresented = false
    
    var body: some View {
        Group {
             if viewModel.products.isEmpty {
                if viewModel.isLoading {
                    ProgressView("Loading products...")
                } else if let error = viewModel.error {
                    Text(error.localizedDescription)
                } else {
                    Text("No products found at the moment.")
                }
            } else {
                List(viewModel.products) { product in
                    Text(product.name)
                }
                .refreshable {
                    await viewModel.fetchProducts()
                }
            }
        }
        .navigationTitle("Products")
        .task {
            await viewModel.fetchProducts()
        }
    }
}

#Preview {
    NavigationStack {
        ProductListView(
            viewModel: ProductListViewModel(
                repository: ProductRepository(
                    productNetworkService: ProductNetworkService(
                        networkService: NetworkService(
                            server: .local,
                            session: .live()
                        )
                    )
                )
            )
        )
    }
}

// MARK: - ProductListViewModel
@MainActor
@Observable
class ProductListViewModel {
    var isLoading = false
    var error: Error?
    private let repository: ProductRepository
    
    var products: [Product] {
        repository.products
    }
    
    init(repository: ProductRepository) {
        self.repository = repository
    }
    
    func fetchProducts() async {
        isLoading = true
        error = nil
        
        do {
            try await repository.fetchAll()
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
}
