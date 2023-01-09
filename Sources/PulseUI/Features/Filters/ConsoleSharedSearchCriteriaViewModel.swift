// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

final class ConsoleSharedSearchCriteriaViewModel: ObservableObject {
    @Published var criteria = ConsoleSharedSearchCriteria()
    @Published var isButtonResetEnabled = false

    private(set) var defaultDates: ConsoleDatesFilter = .default

    let dataNeedsReload = PassthroughSubject<Void, Never>()

    private let store: LoggerStore
    private var cancellables: [AnyCancellable] = []

    init(store: LoggerStore) {
        self.store = store


        if store === LoggerStore.shared {
#if os(iOS) || os(macOS)
            criteria.dates = .session
            defaultDates = .session
#else
            criteria.quickDatesFilter = .session
#endif
        }

        $criteria.dropFirst().sink { [weak self] _ in
            self?.isButtonResetEnabled = true
            DispatchQueue.main.async { // important!
                self?.dataNeedsReload.send()
            }
        }.store(in: &cancellables)
    }

    var isDefaultSearchCriteria: Bool {
        isDatesDefault && criteria.filters == .default
    }

    func resetAll() {
        resetDates()
        criteria.filters = .default
        isButtonResetEnabled = false
    }

    var isDatesDefault: Bool {
        criteria.dates == defaultDates
    }

    func resetDates() {
        criteria.dates = defaultDates
    }

    func removeAllPins() {
        store.pins.removeAllPins()

#if os(iOS)
        runHapticFeedback(.success)
        ToastView {
            HStack {
                Image(systemName: "trash")
                Text("All pins removed")
            }
        }.show()
#endif
    }
}
