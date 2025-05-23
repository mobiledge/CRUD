import Foundation
import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true

let productService = ProductService.live(server: .local, session: .live())

func printDetailedError(_ error: Error) {
    print("Error: \(error)")
    print("Localized Description: \(error.localizedDescription)")
    
    if let nsError = error as NSError? {
        print("Domain: \(nsError.domain)")
        print("Code: \(nsError.code)")
        print("UserInfo: \(nsError.userInfo)")
    }
}

func fetchAllProducts() async {
    print("--- Fetching All Products ---")
    do {
        let products = try await productService.fetchAll()
        print("Success: \(products.count) products fetched")
        products.forEach { print($0) }
    } catch {
        printDetailedError(error)
    }
}

func fetchProductById(id: Int) async {
    print("--- Fetching Product ID \(id) ---")
    do {
        let product = try await productService.fetchById(id)
        print("Success: \(product.name)")
    } catch {
        printDetailedError(error)
    }
}

func createProduct(name: String) async {
    print("--- Creating Product \(name) ---")
    do {
        let product = try await productService.create(Product(id: 0, name: name))
        print("Success: ID \(product.id), Name \(product.name)")
    } catch {
        printDetailedError(error)
    }
}

func updateProduct(id: Int, newName: String) async {
    print("--- Updating Product \(id) ---")
    do {
        let product = try await productService.update(Product(id: id, name: newName))
        print("Success: ID \(product.id), Name \(product.name)")
    } catch {
        printDetailedError(error)
    }
}

func deleteProduct(id: Int) async {
    print("--- Deleting Product \(id) ---")
    do {
        try await productService.delete(id)
        print("Success: Product deleted")
    } catch {
        printDetailedError(error)
    }
}

// Run tasks here
Task {
    await fetchAllProducts()
     await fetchProductById(id: 1)
     await createProduct(name: "New Gadget")
     await updateProduct(id: 1, newName: "Updated Name")
     await deleteProduct(id: 3)

    PlaygroundPage.current.finishExecution()
}
