import SwiftUI

struct ProductEditView: View {
    @State var viewModel: ProductEditViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingDiscardAlert = false

    var body: some View {
        Form {
            Section("Product Name") {
                TextField("Enter product name", text: $viewModel.nameValue)
            }

            Section("Description") {
                TextField("Enter product description",
                          text: $viewModel.descriptionValue,
                          axis: .vertical)
                .lineLimit(3...6)
            }

            Section("Price") {
                TextField("Enter price (e.g., $19.99)", text: $viewModel.priceValue)
                    .keyboardType(.decimalPad)
            }
        }
        .navigationTitle("Edit Product")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    if viewModel.hasChanges {
                        showingDiscardAlert = true
                    } else {
                        dismiss()
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    Task {
                        await viewModel.saveChanges()
                        dismiss()
                    }
                }
                .fontWeight(.semibold)
                .disabled(viewModel.nameValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .alert("Discard Changes?", isPresented: $showingDiscardAlert) {
            Button("Discard", role: .destructive) {
                dismiss()
            }
            Button("Keep Editing", role: .cancel) { }
        } message: {
            Text("You have unsaved changes. Are you sure you want to discard them?")
        }
    }
}

#Preview("ProductEditView") {
    NavigationStack {
        ProductEditView(
            viewModel: ProductEditViewModel(
                product: Product.mock,
                productRepository: ProductRepository(
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


@MainActor
@Observable
final class ProductEditViewModel {
    var nameValue: String
    var descriptionValue: String
    var priceValue: String

    let nameCaption = "Product Name"
    let descriptionCaption = "Description"
    let priceCaption = "Price"

    private var originalProduct: Product
    private(set) var product: Product
    private let productRepository: ProductRepository

    init(product: Product, productRepository: ProductRepository) {
        self.product = product
        self.originalProduct = product
        self.productRepository = productRepository

        self.nameValue = product.name
        self.descriptionValue = product.description ?? ""
        self.priceValue = product.price ?? ""
    }

    // MARK: - Sanitized Values

    private var nameValueSanitized: String {
        nameValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var descriptionValueSanitized: String {
        descriptionValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var priceValueSanitized: String {
        priceValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Change Detection

    var hasChanges: Bool {
        nameValueSanitized != originalProduct.name ||
        descriptionValueSanitized != (originalProduct.description ?? "") ||
        priceValueSanitized != (originalProduct.price ?? "")
    }

    // MARK: - Save

    func saveChanges() async {
        product.name = nameValueSanitized
        product.description = descriptionValueSanitized.isEmpty ? nil : descriptionValueSanitized
        product.price = priceValueSanitized.isEmpty ? nil : priceValueSanitized

        do {
            try await productRepository.update(product)
        } catch {
            print("Failed to save product: \(error)")
        }
    }
}
