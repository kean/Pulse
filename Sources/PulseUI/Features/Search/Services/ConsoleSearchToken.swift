// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation

enum ConsoleSearchToken: Identifiable, Hashable, Codable {
    var id: ConsoleSearchToken { self }

    case filter(ConsoleSearchFilter)
    case scope(ConsoleSearchScope)

    var systemImage: String {
        switch self {
        case .filter: return "line.3.horizontal.decrease.circle.fill"
        case .scope: return "magnifyingglass.circle.fill"
        }
    }

    var title: String {
        switch self {
        case .filter(let filter): return filter.token
        case .scope(let scope): return scope.title
        }
    }
}
