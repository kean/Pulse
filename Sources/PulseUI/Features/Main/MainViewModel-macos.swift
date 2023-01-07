// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(macOS)

final class MainViewModel: ObservableObject {
    var store: LoggerStore { console.store }
    let console: ConsoleViewModel
    var details: ConsoleDetailsRouterViewModel
    let toolbar = ConsoleToolbarViewModel()
    let searchBar = ConsoleSearchBarViewModel()

    private var cancellables: [AnyCancellable] = []

    public init(store: LoggerStore) {
        self.console = ConsoleViewModel(store: store)
        self.details = ConsoleDetailsRouterViewModel()

        toolbar.$isOnlyErrors.sink { [weak self] in
            self?.console.isOnlyErrors = $0
        }.store(in: &cancellables)

        searchBar.$text.sink { [weak self] in
            self?.didChangeSearchText($0)
        }.store(in: &cancellables)
    }

    private func resetSearchBar() {
        if searchBar.text != "" { searchBar.text = "" }
        if console.filterTerm != "" { console.filterTerm = "" }
    }

    private func didChangeSearchText(_ text: String) {
        console.filterTerm = text
    }

    func freeMemory() {
        store.viewContext.reset()
    }
}

final class ConsoleSearchBarViewModel: ObservableObject {
    @Published var text: String = ""

    let onFind = PassthroughSubject<Void, Never>()
}

#endif
