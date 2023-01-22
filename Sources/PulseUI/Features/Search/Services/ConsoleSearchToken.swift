// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import SwiftUI

enum ConsoleSearchToken: Identifiable, Hashable, Codable {
    var id: ConsoleSearchToken { self }

    case filter(ConsoleSearchFilter)
    case scope(ConsoleSearchScope)
    case term(ConsoleSearchTerm)

    var systemImage: String? {
        switch self {
        case .filter: return "line.3.horizontal.decrease.circle.fill"
        case .scope: return "magnifyingglass.circle.fill"
        case .term: return nil
        }
    }

    var title: String {
        switch self {
        case .filter(let filter):
            return filter.filter.token
        case .scope(let scope):
            return scope.title
        case .term(let term):
            guard term.text.count > 10 else {
                return term.text
            }
            var output = ""
            let words = term.text.split(separator: " ")
            for word in words where output.count + word.count < 12 {
                if !output.isEmpty {
                    output.append(" ")
                }
                output += word
            }
            if output.isEmpty {
                output = String(term.text.prefix(12))
            }
            return output + "…"
        }
    }
}
