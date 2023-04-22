// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine

struct ConsoleLabelsSelectionView: View {
    @ObservedObject var viewModel: ConsoleSearchCriteriaViewModel
    @EnvironmentObject private var index: LoggerStoreIndex

    @State private var labels = NSCountedSet()

    var body: some View {
        ConsoleSearchListSelectionView(
            title: "Labels",
            items: index.labels.sorted(),
            id: \.self,
            selection: $viewModel.selectedLabels,
            description: { $0 },
            label: {
                ConsoleSearchListCell(title: $0, details: "\(labels.count(for: $0))")
            }
        )
        .onReceive(viewModel.entities) {
            let messages = $0 as? [LoggerMessageEntity] ?? []
            self.labels = NSCountedSet(array: messages.map(\.label))
        }
    }
}
