// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS)

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 15, tvOS 15, *)
struct ConsoleSearchOccurrence: Identifiable, Equatable, Hashable {
    let id = ConsoleSearchOccurrenceId()
    let scope: ConsoleSearchScope
    let line: Int
    #warning("fix range")
    let range: NSRange
    let text: AttributedString
    let searchContext: RichTextViewModel.SearchContext

    static func == (lhs: ConsoleSearchOccurrence, rhs: ConsoleSearchOccurrence) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        id.hash(into: &hasher)
    }
}

struct ConsoleSearchOccurrenceId: Hashable {
    let id = UUID()
}

#endif
