import SwiftUI

struct ProductListView: View {
    @State var vm: ProductListViewModel
    
    init(vm: ProductListViewModel) {
        self.vm = vm
    }
    
    var body: some View {
        Group {
            if vm.products.isEmpty && vm.isLoading {
                loadingView
            } else if vm.products.isEmpty {
                emptyView
            } else {
                productListView
            }
        }
        .task {
            await vm.fetchProducts()
        }
        .errorAlert(
            error: $vm.error,
            tryAgainAction: {
                Task {
                    await vm.fetchProducts()
                }
            }
        )
    }
    
    private var loadingView: some View {
        ProgressView("Loading Products...")
    }
    
    private var emptyView: some View {
        ContentUnavailableView(
            "No Products",
            systemImage: "shippingbox",
            description: Text("Try adding new items.")
        )
    }
    
    private func errorView(for error: Error) -> some View {
        ErrorView(error: error) {
            Task {
                await vm.fetchProducts()
            }
        }
    }
    
    private var productListView: some View {
        List {
            ForEach(vm.products) { prod in
                Text(prod.title)
            }
        }
        .refreshable {
            Task {
                await vm.fetchProducts()
            }
        }
    }
}


#Preview("Success") {
    ProductListView(
        vm: ProductListViewModel(
            client: ProductClient.mock(
                fetchAll: {
                    Product.mockProducts
                }
            )
        )
    )
}

#Preview("Loading") {
    ProductListView(
        vm: ProductListViewModel(
            client: ProductClient.mock(
                fetchAll: {
                    try await Task.sleep(for: .seconds(5))
                    return Product.mockProducts
                }
            )
        )
    )
}

#Preview("Error") {
    ProductListView(
        vm: ProductListViewModel(
            client: ProductClient.mock(
                fetchAll: {
                    throw URLError(.notConnectedToInternet)
                }
            )
        )
    )
}

#Preview("Empty") {
    ProductListView(
        vm: ProductListViewModel(
            client: ProductClient.mock(
                fetchAll: {
                    []
                }
            )
        )
    )
}

@MainActor
@Observable
final class ProductListViewModel {
    
    var isLoading = false
    var products = [Product]()
    var error: Error? = nil
    
    private let client: ProductClient
    
    init(client: ProductClient) {
        self.client = client
    }
    
    func fetchProducts() async {
        isLoading = true
        do {
            products = try await client.fetchAll()
            error = nil
        } catch {
            self.error = error
        }
        isLoading = false
    }
}
