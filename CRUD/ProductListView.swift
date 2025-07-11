import SwiftUI

struct ProductListView: View {
    var viewModel: ProductListViewModel
    
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
                    
                    NavigationLink {
                        ProductDetailView(
                            viewModel: ProductDetailViewModel(
                                productId: product.id,
                                repository: viewModel.repository
                            )
                        )
                    } label: {
                        ListRow(title: product.name, subtitle: product.price)
                    }
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
                repository: ProductRepository.mock
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
    let repository: ProductRepository
    
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
