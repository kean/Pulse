// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine

@available(iOS 15, *)
struct ConsoleLabelsSelectionView: View {
    @ObservedObject var viewModel: ConsoleFiltersViewModel
    @EnvironmentObject private var index: LoggerStoreIndex

    var body: some View {
        ConsoleSearchListSelectionView(
            title: "Labels",
            items: index.labels.sorted(),
            id: \.self,
            selection: viewModel.bindingForSelectedLabels(index: index),
            description: { $0 },
            label: { Text($0) }
        )
    }
}

private extension ConsoleFiltersViewModel {
    func bindingForSelectedLabels(index: LoggerStoreIndex) -> Binding<Set<String>> {
        Binding(get: {
            if let focused = self.criteria.messages.labels.focused {
                return [focused]
            } else {
                return Set(index.labels).subtracting(self.criteria.messages.labels.hidden)
            }
        }, set: { newValue in
            self.criteria.messages.labels.focused = nil
            self.criteria.messages.labels.hidden = []
            switch newValue.count {
            case 1:
                self.criteria.messages.labels.focused = newValue.first!
            default:
                self.criteria.messages.labels.hidden = Set(index.labels).subtracting(newValue)
            }
        })
    }
}
