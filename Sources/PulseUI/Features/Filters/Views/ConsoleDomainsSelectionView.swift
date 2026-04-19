// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
struct ConsoleDomainsSelectionView: View {
    @ObservedObject var viewModel: ConsoleFiltersViewModel
    @ObservedObject var index: LoggerStoreIndex

    var body: some View {
        ConsoleSearchListSelectionView(
            title: "Hosts",
            items: index.hosts.sorted(),
            id: \.self,
            selection: viewModel.bindingForHosts(index: index),
            description: { $0 },
            label: { Text($0) }
        )
    }
}

extension ConsoleFiltersViewModel {
    package func bindingForHosts(index: LoggerStoreIndex) -> Binding<Set<String>> {
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
