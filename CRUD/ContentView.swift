//
//  ContentView.swift
//  CRUD
//
//  Created by Rabin Joshi on 2025-05-20.
//

import SwiftUI

struct ContentView: View {
    @State private var searchTokens = [Token]()
    var body: some View {
        NavigationSplitView {
            TagListView(searchTokens: $searchTokens)
        } detail: {
            BookmarkListView(searchTokens: $searchTokens)
        }
    }
}

#Preview {
    ContentView()
        .environment(BookmarkRepository.mock())
}

//struct ContentView: View {
//    var body: some View {
//        TabView {
//            Tab("Bookmarks", systemImage: "tray") {
//                NavigationStack {
//                    BookmarkListView()
//                }
//            }
//            Tab("Products", systemImage: "tray") {
//                NavigationStack {
//                    ProductListView(
//                        viewModel: ProductListViewModel(
//                            repository: ProductRepository.live(
//                                server: .local
//                            )
//                        )
//                    )
//                }
//            }
//        }
//    }
//}
