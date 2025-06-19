//
//  CRUDApp.swift
//  CRUD
//
//  Created by Rabin Joshi on 2025-05-20.
//

import SwiftUI

@main
struct CRUDApp: App {
    
    //Bookmarks stuff
    @State private var bookmarkRepository: BookmarkRepository = {
        let repo = BookmarkRepository()
        repo.saveMany(upserting: Bookmark.mockCollection)
        return repo
    }()
    
    private let service = ServiceProvider(networkService: .live(server: .local))
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(service)
                .environment(bookmarkRepository)
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



//class BookmarkRepository: JSONFileCollectionResourceRepository<Bookmark> {
//    override init(service: FileService = .default) {
//        super.init(service: service)
//        self.saveMany(upserting: Bookmark.mockCollection)
//    }
//}
