import SwiftUI

struct ProductEditView: View {
    @State var viewModel: ProductEditViewModel // Changed to @StateObject
    @Environment(\.dismiss) private var dismiss
    @State private var showingDiscardAlert = false
    @State private var showingSaveErrorAlert = false // For displaying save errors

    var body: some View {
        Form {
            Section(viewModel.nameCaption) { // Use caption from ViewModel
                TextField("Enter \(viewModel.nameCaption.lowercased())", text: $viewModel.nameValue)
            }

            Section(viewModel.descriptionCaption) { // Use caption from ViewModel
                TextField("Enter \(viewModel.descriptionCaption.lowercased())",
                          text: $viewModel.descriptionValue,
                          axis: .vertical)
                .lineLimit(3...6)
            }

            Section(viewModel.priceCaption) { // Use caption from ViewModel
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
                        if viewModel.errorMessage == nil { // Check for error
                            dismiss() // Dismiss only if save was successful
                        } else {
                            showingSaveErrorAlert = true // Show error alert
                        }
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
        .alert("Error Saving Product", isPresented: $showingSaveErrorAlert) { // Alert for save errors
            Button("OK", role: .cancel) { }
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


@MainActor
@Observable
final class ProductEditViewModel {
    
    var errorMessage: String?
    
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

    // MARK: - Edited Product with Inlined Sanitization
    
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
    
    // MARK: - Change Detection
    
    var hasChanges: Bool {
        editedProduct.name != originalProduct.name ||
        editedProduct.description != originalProduct.description ||
        editedProduct.price != originalProduct.price
    }

    // MARK: - Save

    func saveChanges() async {
        self.errorMessage = nil
        do {
            try await productRepository.update(editedProduct)
        } catch {
            self.errorMessage = "Could not save product: \(error.localizedDescription)"
        }
    }
}
