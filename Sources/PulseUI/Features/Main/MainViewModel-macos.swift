// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(macOS)

final class MainViewModel: ObservableObject {
    var store: LoggerStore { console.store }
    let console: ConsoleViewModel
    let network: NetworkViewModel
    var details = ConsoleDetailsPanelViewModel()
    let toolbar = ConsoleToolbarViewModel()
    let mode = ConsoleModePickerViewModel()
    let searchBar = ConsoleSearchBarViewModel()

    private var cancellables: [AnyCancellable] = []

    public init(store: LoggerStore) {
        self.console = ConsoleViewModel(store: store)
        self.network = NetworkViewModel(store: store)

        toolbar.$isOnlyErrors.sink { [weak self] in
            self?.console.isOnlyErrors = $0
            self?.network.isOnlyErrors = $0
        }.store(in: &cancellables)

        mode.$isNetworkOnly.sink { [weak self] _ in
            self?.resetSearchBar()
        }.store(in: &cancellables)

        searchBar.$text.sink { [weak self] in
            self?.didChangeSearchText($0)
        }.store(in: &cancellables)
    }

    private func resetSearchBar() {
        if searchBar.text != "" { searchBar.text = "" }
        if console.filterTerm != "" { console.filterTerm = "" }
        if network.filterTerm != "" { network.filterTerm = "" }
    }

    private func didChangeSearchText(_ text: String) {
        if mode.isNetworkOnly {
            network.filterTerm = text
        } else {
            console.filterTerm = text
        }
    }
}

final class ConsoleModePickerViewModel: ObservableObject {
    @Published var isNetworkOnly = false
}

final class ConsoleSearchBarViewModel: ObservableObject {
    @Published var text: String = ""

    let onFind = PassthroughSubject<Void, Never>()
}

#endif
