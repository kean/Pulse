// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS) || os(visionOS)

import Foundation
import SwiftUI

enum ConsoleSearchToken: Identifiable, Hashable, Codable {
    var id: ConsoleSearchToken { self }

    case term(ConsoleSearchTerm)

    var systemImage: String? {
        switch self {
        case .term: return nil
        }
    }

    var title: String {
        switch self {
        case .term(let term):
            return term.text // This should never be used
        }
    }
}

#endif
