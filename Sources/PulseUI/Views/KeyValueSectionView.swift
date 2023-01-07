// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct KeyValueSectionViewModel {
    var title: String
    var color: Color
    var action: ActionViewModel?
    var items: [(String, String?)] = []

    @available(*, deprecated, message: "Deprecated")
    func title(_ title: String) -> KeyValueSectionViewModel {
        var copy = self
        copy.title = title
        return copy
    }

    @available(*, deprecated, message: "Deprecated")
    static func empty() -> KeyValueSectionViewModel {
        KeyValueSectionViewModel(title: "Empty", color: .secondary)
    }
}

struct KeyValueRow: Identifiable {
    let id: Int
    let item: (String, String?)

    var title: String { item.0 }
    var details: String? { item.1 }
}

@available(*, deprecated, message: "Deprecated")
struct ActionViewModel {
    let title: String
    let action: () -> Void
}
