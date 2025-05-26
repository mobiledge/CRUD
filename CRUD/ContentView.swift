//
//  ContentView.swift
//  CRUD
//
//  Created by Rabin Joshi on 2025-05-20.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ProductListView(
                vm: ProductListViewModel(
                    service: ProductService.live(
                        server: .local,
                        session: .live()
                    )
                )
            )
        }
    }
}

#Preview {
    ContentView()
}
