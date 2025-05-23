//
//  ContentView.swift
//  CRUD
//
//  Created by Rabin Joshi on 2025-05-20.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ProductListView(
            vm: ProductListViewModel(
                client: ProductClient.live(
                    server: .prod,
                    session: .live()
                )
            )
        )
    }
}

#Preview {
    ContentView()
}
