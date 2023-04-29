// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine

struct ConsoleLabelsSelectionView: View {
    @ObservedObject var viewModel: ConsoleFiltersViewModel
    @EnvironmentObject private var index: LoggerStoreIndex

    @State private var labels = NSCountedSet()

    var body: some View {
        ConsoleSearchListSelectionView(
            title: "Labels",
            items: index.labels.sorted(),
            id: \.self,
            selection: viewModel.bindingForSelectedLabels(index: index),
            description: { $0 },
            label: {
                ConsoleSearchListCell(title: $0, details: "\(labels.count(for: $0))")
            }
        )
        .onReceive(viewModel.entities) {
            let messages = $0 as? [LoggerMessageEntity] ?? []
            self.labels = NSCountedSet(array: messages.map(\.label))
        }
        .onAppear {
            let messages = viewModel.entities.value as? [LoggerMessageEntity] ?? []
            self.labels = NSCountedSet(array: messages.map(\.label))
        }
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
