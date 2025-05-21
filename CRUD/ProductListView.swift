//
//  ProductListView.swift
//  CRUD
//
//  Created by Rabin Joshi on 2025-05-20.
//

import SwiftUI

struct ProductListView: View {
    
    @State var vm: ProductListViewModel
    init(vm: ProductListViewModel) {
        self.vm = vm
    }
    
    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView("Loading products...")
            } else if let error = vm.errorDescription {
                Text(error)
            } else {
                List {
                    ForEach(vm.products) { prod in
                        Text(prod.title)
                    }
                }
            }
        }
        .task {
            await vm.fetchProducts()
        }
    }
}

#Preview("Success") {
    ProductListView(
        vm: ProductListViewModel(
            client: ProductClient.mock(fetchAll: {
                Product.mockProducts
            }                      )
        )
    )
}

#Preview("Loading") {
    ProductListView(
        vm: ProductListViewModel(
            client: ProductClient.mock(fetchAll: {
                try await Task.sleep(nanoseconds: UInt64.max)
                return []
            })
        )
    )
}

#Preview("Error") {
    ProductListView(
        vm: ProductListViewModel(
            client: ProductClient.mock(fetchAll: {
                throw NSError(domain: "ProductClient.Mock", code: 404, userInfo: [NSLocalizedDescriptionKey: "Product not found"])
            })
        )
    )
}


@Observable
final class ProductListViewModel {
    var isLoading: Bool
    var errorDescription: String?
    var products: [Product]
    
    private let client: ProductClient
    
    init(client: ProductClient) {
        self.isLoading = false
        self.errorDescription = nil
        self.products = []
        self.client = client
    }
    
    func fetchProducts() async {
        isLoading = true
        defer {
            isLoading = false
        }
        do {
            products = try await client.fetchAll()
        } catch {
            errorDescription = error.localizedDescription
        }
    }
}
