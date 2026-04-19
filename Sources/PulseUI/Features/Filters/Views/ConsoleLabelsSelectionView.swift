// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
struct ConsoleLabelsSelectionView: View {
    @ObservedObject var viewModel: ConsoleFiltersViewModel
    @ObservedObject var index: LoggerStoreIndex

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

extension ConsoleFiltersViewModel {
    package func bindingForSelectedLabels(index: LoggerStoreIndex) -> Binding<Set<String>> {
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
