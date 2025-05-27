import SwiftUI

struct ProductDetailView: View {
    @State var viewModel: ProductDetailViewModel

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading product...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 16) {
                    Text("Error")
                        .font(.headline)
                    Text(errorMessage)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.red)
                    Button("Retry") {
                        Task {
                            await viewModel.loadProduct()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Product Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text(viewModel.nameCaption)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            Text(viewModel.nameValue)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }

                        // Description
                        if let description = viewModel.descriptionValue, !description.isEmpty {
                            Divider()
                            VStack(alignment: .leading, spacing: 8) {
                                Text(viewModel.descriptionCaption)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                
                                Text(description)
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                        }

                        // Price
                        if let price = viewModel.priceValue, !price.isEmpty {
                            Divider()
                            VStack(alignment: .leading, spacing: 8) {
                                Text(viewModel.priceCaption)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                
                                Text(price)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                        }

                        Spacer(minLength: 20)
                    }
                    .padding()
                }
            }
        }
        .task {
            await viewModel.loadProduct()
        }
        .navigationTitle("Product Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    viewModel.showingEditView = true
                }
                .disabled(viewModel.product == nil)
            }
        }
        .sheet(isPresented: $viewModel.showingEditView) {
            if let product = viewModel.product {
                NavigationView {
                    ProductEditView(
                        viewModel: ProductEditViewModel(
                            product: product,
                            productRepository: viewModel.repository
                        )
                    )
                }
            }
        }
    }
}


#Preview("ProductDetailView") {
    NavigationStack {
        ProductDetailView(
            viewModel: ProductDetailViewModel(
                productId: 1,
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


import Observation

@MainActor
@Observable
final class ProductDetailViewModel {
    var product: Product? {
        repository.products.first(where: { $0.id == productId })
    }
    var isLoading: Bool = false
    var errorMessage: String?
    var showingEditView: Bool = false

    let repository: ProductRepository
    private let productId: Int

    var nameCaption: String { "Product Name" }
    var nameValue: String { product?.name ?? "-" }

    var descriptionCaption: String { "Description" }
    var descriptionValue: String? { product?.description }

    var priceCaption: String { "Price" }
    var priceValue: String? { product?.price }

    init(productId: Int, repository: ProductRepository) {
        self.productId = productId
        self.repository = repository
    }

    func loadProduct() async {
        self.isLoading = true
        self.errorMessage = nil
        do {
            try await repository.fetchById(productId)
        } catch {
            self.errorMessage = "Failed to load product: \(error.localizedDescription)"
        }
        self.isLoading = false
    }
}
