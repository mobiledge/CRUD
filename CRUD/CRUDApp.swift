//
//  CRUDApp.swift
//  CRUD
//
//  Created by Rabin Joshi on 2025-05-20.
//

import SwiftUI

@main
struct CRUDApp: App {
    
    private let service = ServiceProvider(networkService: .live(server: .local))
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(service)
        }
    }
}


@Observable
final class ServiceProvider {
    let networkService: NetworkService

    init(networkService: NetworkService) {
        self.networkService = networkService
    }
}
