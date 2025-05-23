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
    ProductListView(vm: ProductListViewModel(service: .mockHappyPath))
}

#Preview("Loading") {
    ProductListView(
        vm: ProductListViewModel(service: .mock(fetchAll: {
            try await Task.sleep(for: .seconds(2))
            return []
        }))
    )
}

#Preview("Error") {
    ProductListView(
        vm: ProductListViewModel(
            service: .mockError(URLError(.notConnectedToInternet))
        )
    )
}

#Preview("Empty") {
    ProductListView(vm: ProductListViewModel(service: .mock(fetchAll: {
        []
    })))
}

@MainActor
@Observable
final class ProductListViewModel {
    
    var isLoading = false
    var products = [Product]()
    var error: Error? = nil
    
    private let service: FetchAllProductsService
    
    init(service: FetchAllProductsService) {
        self.service = service
    }
    
    func fetchProducts() async {
        isLoading = true
        do {
            products = try await service.fetchAll()
            error = nil
        } catch {
            self.error = error
        }
        isLoading = false
    }
}
