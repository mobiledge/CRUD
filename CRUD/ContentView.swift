//
//  ContentView.swift
//  CRUD
//
//  Created by Rabin Joshi on 2025-05-20.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Bookmarks", systemImage: "tray") {
                NavigationStack {
                    BookmarkListView()
                }
            }
            Tab("Products", systemImage: "tray") {
                NavigationStack {
                    ProductListView(
                        viewModel: ProductListViewModel(
                            repository: ProductRepository.live(
                                server: .local
                            )
                        )
                    )
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
