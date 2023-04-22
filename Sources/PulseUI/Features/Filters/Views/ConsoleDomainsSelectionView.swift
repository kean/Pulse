// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine

struct ConsoleDomainsSelectionView: View {
    @ObservedObject var viewModel: ConsoleSearchCriteriaViewModel
    @EnvironmentObject private var index: LoggerStoreIndex

    @State private var domains = NSCountedSet()

    var body: some View {
        ConsoleSearchListSelectionView(
            title: "Hosts",
            items: index.hosts.sorted(),
            id: \.self,
            selection: $viewModel.selectedHost,
            description: { $0 },
            label: {
                ConsoleSearchListCell(title: $0, details: "\(domains.count(for: $0))")
            }
        )
        .onReceive(viewModel.entities) {
            let tasks = $0 as? [NetworkTaskEntity] ?? []
            self.domains = NSCountedSet(array: tasks.compactMap(\.host))
        }
    }
}
