// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

final class ConsoleSharedSearchCriteriaViewModel: ObservableObject {
    @Published var dates = ConsoleMessageSearchCriteria.DatesFilter.default
    private(set) var defaultDates: ConsoleMessageSearchCriteria.DatesFilter = .default

    let dataNeedsReload = PassthroughSubject<Void, Never>()

    @Published var isButtonResetEnabled = false

    private var cancellables: [AnyCancellable] = []

    init(store: LoggerStore) {
        if store !== LoggerStore.shared {
            dates.isCurrentSessionOnly = false
            defaultDates.isCurrentSessionOnly = false
        }

        $dates.dropFirst().sink { [weak self] _ in
            self?.isButtonResetEnabled = true
            DispatchQueue.main.async { // important!
                self?.dataNeedsReload.send()
            }
        }.store(in: &cancellables)
    }

    var isDefaultSearchCriteria: Bool {
        dates == defaultDates
    }

    func resetAll() {
        dates = defaultDates
        isButtonResetEnabled = false
    }
}
