// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Combine
import Pulse
import PulseComponents

@available(iOS 15, visionOS 1.0, *)
struct ConsoleDomainsSelectionView: View {
    @ObservedObject var viewModel: ConsoleFiltersViewModel
    @EnvironmentObject private var index: LoggerStoreIndex

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
