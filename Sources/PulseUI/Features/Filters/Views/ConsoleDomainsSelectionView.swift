// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine

@available(iOS 15, *)
struct ConsoleDomainsSelectionView: View {
    @ObservedObject var viewModel: ConsoleFiltersViewModel
    @EnvironmentObject private var index: LoggerStoreIndex

    @State private var domains = NSCountedSet()

    var body: some View {
        ConsoleSearchListSelectionView(
            title: "Hosts",
            items: index.hosts.sorted(),
            id: \.self,
            selection: viewModel.bindingForHosts(index: index),
            description: { $0 },
            label: {
                ConsoleSearchListCell(title: $0, details: "\(domains.count(for: $0))")
            }
        )
        .onReceive(viewModel.entities) {
            let tasks = $0 as? [NetworkTaskEntity] ?? []
            self.domains = NSCountedSet(array: tasks.compactMap(\.host))
        }
        .onAppear {
            let tasks = viewModel.entities.value as? [NetworkTaskEntity] ?? []
            self.domains = NSCountedSet(array: tasks.compactMap(\.host))
        }
    }
}   

private extension ConsoleFiltersViewModel {
    func bindingForHosts(index: LoggerStoreIndex) -> Binding<Set<String>> {
        Binding(get: {
            if let focused = self.criteria.network.host.focused {
                return [focused]
            } else {
                return Set(index.hosts).subtracting(self.criteria.network.host.hidden)
            }
        }, set: { newValue in
            self.criteria.network.host.focused = nil
            self.criteria.network.host.hidden = []
            switch newValue.count {
            case 1:
                self.criteria.network.host.focused = newValue.first!
            default:
                self.criteria.network.host.hidden = Set(index.hosts).subtracting(newValue)
            }
        })
    }
}
