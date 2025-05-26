import SwiftUI

struct ProductDetailView: View {
    @State private var product: Product
    @State private var showingEditView = false
    
    init(product: Product) {
        self._product = State(initialValue: product)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Product Name Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Product Name")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Text(product.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                // Description Section
                if let description = product.description, !description.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        Text(description)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineLimit(nil)
                    }
                }
                
                // Price Section
                if let price = product.price, !price.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Price")
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
        .navigationTitle("Product Details")
        .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Edit") {
                            showingEditView = true
                        }
                    }
                }
                .sheet(isPresented: $showingEditView) {
                    NavigationView {
                        ProductEditView(product: $product)
                    }
                }
    }
}

#Preview("Standard Layout") {
    NavigationView {
        ProductDetailView(product: Product(
            id: 12345,
            name: "Premium Wireless Headphones",
            description: "High-quality wireless headphones with noise cancellation, premium sound quality, and long-lasting battery life. Perfect for music lovers and professionals.",
            price: "$299.99"
        ))
    }
}
