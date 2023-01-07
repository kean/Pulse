// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

@available(*, deprecated, message: "Deprecated")
struct KeyValueSectionView: View {
    let viewModel: KeyValueSectionViewModel
    var limit: Int = Int.max
    private var hideTitle = false
    private var hideAction = false

    init(viewModel: KeyValueSectionViewModel) {
        self.viewModel = viewModel
    }

    init(viewModel: KeyValueSectionViewModel, limit: Int) {
        self.viewModel = viewModel
        self.limit = limit
    }

    func hiddenTitle() -> KeyValueSectionView {
        var copy = self
        copy.hideTitle = true
        return copy
    }

    func hiddenAction() -> KeyValueSectionView {
        var copy = self
        copy.hideAction = true
        return copy
    }

    var body: some View {
        Text("Deprecated")
    }
}

@available(*, deprecated, message: "Deprecated")
private struct KeyValueListView: View {
    let viewModel: KeyValueSectionViewModel
    var limit: Int = Int.max

    var body: some View {
        Text("Deprecated")
    }
}

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
