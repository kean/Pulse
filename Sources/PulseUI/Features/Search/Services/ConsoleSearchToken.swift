// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS)

import Foundation
import SwiftUI

enum ConsoleSearchToken: Identifiable, Hashable, Codable {
    var id: ConsoleSearchToken { self }

    case filter(ConsoleSearchFilter)
    case term(ConsoleSearchTerm)

    var systemImage: String? {
        switch self {
        case .filter: return "line.3.horizontal.decrease.circle.fill"
        case .term: return nil
        }
    }

    var title: String {
        switch self {
        case .filter(let filter):
            return filter.filter.token
        case .term(let term):
            return term.text // This should never be used
        }
    }
}

#endif
