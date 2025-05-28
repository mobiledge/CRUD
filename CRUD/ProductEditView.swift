import SwiftUI

// MARK: - Product Edit View

struct ProductEditView: View {
    // MARK: - Properties
    
    @State var viewModel: ProductEditViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingDiscardAlert = false
    @State private var showingErrorAlert = false
    @State private var showingDeleteConfirmAlert = false
    
    // MARK: - Body
    
    var body: some View {
        Form {
            nameSection
            descriptionSection
            priceSection
            deleteSection
        }
        .navigationTitle("Edit Product")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarContent()
        }
        .alert("Discard Changes?", isPresented: $showingDiscardAlert, actions: discardAlertActions, message: discardAlertMessage)
        .alert("Confirm Deletion", isPresented: $showingDeleteConfirmAlert, actions: deleteConfirmAlertActions, message: deleteConfirmAlertMessage)
        .alert("Error", isPresented: $showingErrorAlert, actions: errorAlertActions, message: errorAlertMessage)
    }
    
    // MARK: - View Components
    
    private var nameSection: some View {
        Section {
            TextField(ProductEditViewModel.namePlaceholder, text: $viewModel.nameValue)
        } header: {
            Text(ProductEditViewModel.nameCaption)
        } footer: {
            Text(ProductEditViewModel.nameFooterText)
        }
    }
    
    private var descriptionSection: some View {
        Section {
            TextField(
                ProductEditViewModel.descriptionPlaceholder,
                text: $viewModel.descriptionValue,
                axis: .vertical
            )
            .lineLimit(3...6)
        } header: {
            Text(ProductEditViewModel.descriptionCaption)
        } footer: {
            Text(ProductEditViewModel.descriptionFooterText)
        }
    }
    
    private var priceSection: some View {
        Section {
            TextField(ProductEditViewModel.pricePlaceholder, text: $viewModel.priceValue)
                .keyboardType(.decimalPad)
        } header: {
            Text(ProductEditViewModel.priceCaption)
        } footer: {
            Text(ProductEditViewModel.priceFooterText)
        }
    }
    
    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showingDeleteConfirmAlert = true
            } label: {
                Text("Delete Product")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        } footer: {
            Text(ProductEditViewModel.deleteFooterText)
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") {
                handleCancel()
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Save") {
                Task {
                    await handleSave()
                }
            }
            .fontWeight(.semibold)
            .disabled(viewModel.nameValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !viewModel.hasChanges)
        }
    }
    
    // MARK: - Alert Actions & Messages
    
    @ViewBuilder
    private func discardAlertActions() -> some View {
        Button("Discard", role: .destructive) { dismiss() }
        Button("Keep Editing", role: .cancel) {}
    }
    
    private func discardAlertMessage() -> Text {
        Text("You have unsaved changes. Are you sure you want to discard them?")
    }
    
    @ViewBuilder
    private func deleteConfirmAlertActions() -> some View {
        Button("Delete", role: .destructive) {
            Task {
                await handleDelete()
            }
        }
        Button("Cancel", role: .cancel) {}
    }
    
    private func deleteConfirmAlertMessage() -> Text {
        Text("Are you sure you want to delete this product? This action cannot be undone.")
    }
    
    @ViewBuilder
    private func errorAlertActions() -> some View {
        Button("OK", role: .cancel) {}
    }
    
    private func errorAlertMessage() -> Text {
        Text(viewModel.errorMessage ?? "An unknown error occurred.")
    }
    
    // MARK: - Helper Methods
    
    private func handleCancel() {
        if viewModel.hasChanges {
            showingDiscardAlert = true
        } else {
            dismiss()
        }
    }
    
    private func handleSave() async {
        await viewModel.saveChanges()
        if viewModel.errorMessage == nil {
            dismiss()
        } else {
            showingErrorAlert = true
        }
    }
    
    private func handleDelete() async {
        await viewModel.deleteProduct()
        if viewModel.errorMessage == nil {
            dismiss()
        } else {
            showingErrorAlert = true
        }
    }
}

// MARK: - Preview

#Preview("ProductEditView - Light") {
    NavigationStack {
        ProductEditView(
            viewModel: ProductEditViewModel(
                product: Product.mockValue,
                productRepository: ProductRepository(
                    productNetworkService: LiveProductNetworkService(
                        networkService: NetworkService(
                            server: .local,
                            session: .live()
                        )
                    )
                )
            )
        )
    }
    .preferredColorScheme(.light)
}

#Preview("ProductEditView - Dark") {
    NavigationStack {
        ProductEditView(
            viewModel: ProductEditViewModel(
                product: Product.mockValue,
                productRepository: ProductRepository(
                    productNetworkService: LiveProductNetworkService(
                        networkService: NetworkService(
                            server: .local,
                            session: .live()
                        )
                    )
                )
            )
        )
    }
    .preferredColorScheme(.dark)
}

// MARK: - Product Edit ViewModel

@MainActor
@Observable
final class ProductEditViewModel {
    // MARK: - Published Properties
    
    var nameValue: String
    var descriptionValue: String
    var priceValue: String
    var errorMessage: String?
    
    // MARK: - Static UI Content
    
    static let nameCaption = "Product Name"
    static let descriptionCaption = "Description"
    static let priceCaption = "Price"
    
    static let namePlaceholder = "Enter product name"
    static let descriptionPlaceholder = "Enter product description"
    static let pricePlaceholder = "Enter price (e.g., 19.99)"
    
    static let nameFooterText = "The official name of the product."
    static let descriptionFooterText = "A brief summary of the product. This will be shown to customers."
    static let priceFooterText = "Set the price for the product (e.g., 19.99)."
    static let deleteFooterText = "Deleting a product cannot be undone."
    
    // MARK: - Private Properties
    
    private var originalProduct: Product
    private(set) var product: Product // Current state, updated on successful save
    private let productRepository: ProductRepository
    
    // MARK: - Computed Properties
    
    /// A computed version of the product based on current form values.
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
    
    /// Indicates if there are any unsaved changes compared to the original product.
    var hasChanges: Bool {
        editedProduct.name != originalProduct.name ||
        editedProduct.description != originalProduct.description ||
        editedProduct.price != originalProduct.price
    }
    
    // MARK: - Initialization
    
    init(product: Product, productRepository: ProductRepository) {
        self.product = product
        self.originalProduct = product // Store the initial state for comparison
        self.productRepository = productRepository
        
        // Initialize form values from the product
        self.nameValue = product.name
        self.descriptionValue = product.description ?? ""
        self.priceValue = product.price ?? ""
    }
    
    // MARK: - Public Methods
    
    /// Attempts to save the changes made to the product.
    /// Updates `errorMessage` on failure.
    func saveChanges() async {
        self.errorMessage = nil // Clear previous errors
        let productToSave = self.editedProduct
        
        do {
            try await productRepository.update(productToSave)
            self.product = productToSave         // Update current product state
            self.originalProduct = productToSave // Update original to reflect saved state
        } catch {
            self.errorMessage = "Could not save product: \(error.localizedDescription)"
        }
    }
    
    /// Attempts to delete the current product.
    /// Updates `errorMessage` on failure.
    func deleteProduct() async {
        self.errorMessage = nil // Clear previous errors
        do {
            try await productRepository.delete(self.product.id)
        } catch {
            self.errorMessage = "Could not delete product: \(error.localizedDescription)"
        }
    }
}
