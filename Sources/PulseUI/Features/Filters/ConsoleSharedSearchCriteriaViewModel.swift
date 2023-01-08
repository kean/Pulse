// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

final class ConsoleSharedSearchCriteriaViewModel: ObservableObject {
    @Published var dates = ConsoleDatesFilter.default
    private(set) var defaultDates: ConsoleDatesFilter = .default

    @Published var filters = ConsoleGeneralFilters.default

    let dataNeedsReload = PassthroughSubject<Void, Never>()

    @Published var isButtonResetEnabled = false

    private let store: LoggerStore
    private var cancellables: [AnyCancellable] = []

    init(store: LoggerStore) {
        self.store = store

        if store === LoggerStore.shared {
            dates = .session
            defaultDates = .session
        }

        Publishers.CombineLatest($dates, $filters).dropFirst().sink { [weak self] _ in
            self?.isButtonResetEnabled = true
            DispatchQueue.main.async { // important!
                self?.dataNeedsReload.send()
            }
        }.store(in: &cancellables)
    }

    var isDefaultSearchCriteria: Bool {
        isDatesDefault && filters == .default
    }

    func resetAll() {
        resetDates()
        filters = .default
        isButtonResetEnabled = false
    }

    var isDatesDefault: Bool {
        dates == defaultDates
    }

    func resetDates() {
        dates = defaultDates
    }

    func removeAllPins() {
        store.pins.removeAllPins()

        runHapticFeedback(.success)
        ToastView {
            HStack {
                Image(systemName: "trash")
                Text("All pins removed")
            }
        }.show()
    }
}
