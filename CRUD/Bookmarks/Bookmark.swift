//
//  Bookmark.swift
//  CRUD
//
//  Created by Rabin Joshi on 2025-06-19.
//

import Foundation

struct Bookmark: Codable, Identifiable  {
    let id: String
    let url: URL
    let tags: Set<String>
}

extension Bookmark: FileCollectionResource {
    typealias Item = Self
}
