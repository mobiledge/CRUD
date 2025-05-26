import SwiftUI

struct ProductEditView: View {
    @Binding var product: Product
    @Environment(\.dismiss) private var dismiss
    
    @State private var editedName: String = ""
    @State private var editedDescription: String = ""
    @State private var editedPrice: String = ""
    @State private var showingDiscardAlert = false
    
    var body: some View {
        Form {
            Section("Product Name") {
                TextField("Enter product name", text: $editedName)
            }
            
            Section("Description") {
                TextField("Enter product description",
                          text: $editedDescription,
                          axis: .vertical)
                .lineLimit(3...6)
            }
            
            Section("Price") {
                TextField("Enter price (e.g., $19.99)", text: $editedPrice)
                    .keyboardType(.decimalPad)
            }
        }
        .navigationTitle("Edit Product")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    if hasChanges {
                        showingDiscardAlert = true
                    } else {
                        dismiss()
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveChanges()
                    dismiss()
                }
                .fontWeight(.semibold)
                .disabled(editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            setupInitialValues()
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
    
    private func setupInitialValues() {
        editedName = product.name
        editedDescription = product.description ?? ""
        editedPrice = product.price ?? ""
    }
    
    private func saveChanges() {
        product.name = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        product.description = editedDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        product.price = editedPrice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editedPrice.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var hasChanges: Bool {
        let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = editedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPrice = editedPrice.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return trimmedName != product.name ||
        trimmedDescription != (product.description ?? "") ||
        trimmedPrice != (product.price ?? "")
    }
}

#Preview("Product Edit View") {
    NavigationView {
        ProductEditView(product: .constant(Product(
            id: 12345,
            name: "Premium Wireless Headphones",
            description: "High-quality wireless headphones with noise cancellation, premium sound quality, and long-lasting battery life. Perfect for music lovers and professionals.",
            price: "$299.99"
        )))
    }
}
