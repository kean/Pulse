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

    let dataNeedsReload = PassthroughSubject<Void, Never>()

    @Published var isButtonResetEnabled = false

    private var cancellables: [AnyCancellable] = []

    init(store: LoggerStore) {
        if store === LoggerStore.shared {
            dates = .session
            defaultDates = .session
        }

        $dates.dropFirst().sink { [weak self] _ in
            self?.isButtonResetEnabled = true
            DispatchQueue.main.async { // important!
                self?.dataNeedsReload.send()
            }
        }.store(in: &cancellables)
    }

    var isDefaultSearchCriteria: Bool {
        isDatesDefault
    }

    func resetAll() {
        resetDates()
        isButtonResetEnabled = false
    }

    var isDatesDefault: Bool {
        dates == defaultDates
    }

    func resetDates() {
        dates = defaultDates
    }
}
