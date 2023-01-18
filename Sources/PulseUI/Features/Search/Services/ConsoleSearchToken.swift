// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import SwiftUI

enum ConsoleSearchToken: Identifiable, Hashable, Codable {
    var id: ConsoleSearchToken { self }

    case filter(ConsoleSearchFilter)
    case scope(ConsoleSearchScope)
    case text(String)

    var systemImage: String? {
        switch self {
        case .filter: return "line.3.horizontal.decrease.circle.fill"
        case .scope: return "magnifyingglass.circle.fill"
        case .text: return nil
        }
    }

    var title: String {
        switch self {
        case .filter(let filter): return filter.token
        case .scope(let scope): return scope.title
        case .text(let text):
            guard text.count > 10 else {
                return text
            }
            var output = ""
            let words = text.split(separator: " ")
            for word in words where output.count + word.count < 12 {
                if !output.isEmpty {
                    output.append(" ")
                }
                output += word
            }
            return output + "…"
        }
    }
}
