import SwiftUI

struct ProductEditView: View {
    @State var viewModel: ProductEditViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingDiscardAlert = false
    @State private var showingErrorAlert = false // Renamed for generic errors
    @State private var showingDeleteConfirmAlert = false

    var body: some View {
        Form {
            Section {
                TextField("Enter \(viewModel.nameCaption.lowercased())", text: $viewModel.nameValue)
            } header: {
                Text(viewModel.nameCaption)
            } footer: {
                Text("The official name of the product.")
            }

            Section {
                TextField("Enter \(viewModel.descriptionCaption.lowercased())",
                          text: $viewModel.descriptionValue,
                          axis: .vertical)
                .lineLimit(3...6)
            } header: {
                Text(viewModel.descriptionCaption)
            } footer: {
                Text("A brief summary of the product. This will be shown to customers.")
            }

            Section {
                TextField("Enter price", text: $viewModel.priceValue)
                    .keyboardType(.decimalPad)
            } header: {
                Text(viewModel.priceCaption)
            } footer: {
                Text("Set the price for the product (e.g., 19.99).")
            }

            // Section for Delete Button
            Section {
                Button(role: .destructive) {
                    showingDeleteConfirmAlert = true
                } label: {
                    Text("Delete Product")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } footer: {
                Text("Deleting a product cannot be undone.")
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
                        if viewModel.errorMessage == nil {
                            dismiss()
                        } else {
                            showingErrorAlert = true
                        }
                    }
                }
                .fontWeight(.semibold)
                .disabled(viewModel.nameValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !viewModel.hasChanges) // Disable if no changes
            }
        }
        .alert("Discard Changes?", isPresented: $showingDiscardAlert) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("You have unsaved changes. Are you sure you want to discard them?")
        }
        .alert("Confirm Deletion", isPresented: $showingDeleteConfirmAlert) {
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteProduct()
                    if viewModel.errorMessage == nil {
                        dismiss()
                    } else {
                        showingErrorAlert = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this product? This action cannot be undone.")
        }
        .alert("Error", isPresented: $showingErrorAlert) { // Generic error alert
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
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

import SwiftUI // Required for @MainActor and @Observable

@MainActor
@Observable
final class ProductEditViewModel {
    var nameValue: String
    var descriptionValue: String
    var priceValue: String

    var errorMessage: String?

    let nameCaption = "Product Name"
    let descriptionCaption = "Description"
    let priceCaption = "Price"

    var originalProduct: Product
    private(set) var product: Product
    private let productRepository: ProductRepository // Assume this has delete(id:)

    init(product: Product, productRepository: ProductRepository) {
        self.product = product
        self.originalProduct = product
        self.productRepository = productRepository

        self.nameValue = product.name
        self.descriptionValue = product.description ?? ""
        self.priceValue = product.price ?? ""
    }

    private var editedProduct: Product {
        let sanitizedName = nameValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedDescription = descriptionValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedPrice = priceValue.trimmingCharacters(in: .whitespacesAndNewlines)

        return Product(
            id: originalProduct.id,
            name: sanitizedName,
            description: sanitizedDescription.isEmpty ? nil : sanitizedDescription,
            price: sanitizedPrice.isEmpty ? nil : sanitizedPrice
        )
    }

    var hasChanges: Bool {
        editedProduct.name != originalProduct.name ||
        editedProduct.description != originalProduct.description ||
        editedProduct.price != originalProduct.price
    }

    func saveChanges() async {
        self.errorMessage = nil
        let productToSave = self.editedProduct

        do {
            try await productRepository.update(productToSave)
            self.product = productToSave
        } catch {
            self.errorMessage = "Could not save product: \(error.localizedDescription)"
        }
    }

    func deleteProduct() async {
        self.errorMessage = nil
        do {
            try await productRepository.delete(self.product.id)
        } catch {
            self.errorMessage = "Could not delete product: \(error.localizedDescription)"
        }
    }
}
