// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

final class ConsoleMessageSearchCriteriaViewModel: ObservableObject {
    @Published var criteria: ConsoleMessageSearchCriteria = .default
    private(set) var defaultCriteria: ConsoleMessageSearchCriteria = .default
    @Published var filters: [ConsoleCustomMessageFilter] = []

    @Published private(set) var isButtonResetEnabled = false

    let dataNeedsReload = PassthroughSubject<Void, Never>()

    private var cancellables: [AnyCancellable] = []

    init(store: LoggerStore) {
//        resetFilters()

        $criteria.dropFirst().sink { [weak self] _ in
            self?.isButtonResetEnabled = true
            DispatchQueue.main.async { // important!
                self?.dataNeedsReload.send()
            }
        }.store(in: &cancellables)
    }

    var isDefaultSearchCriteria: Bool {
        true
//        criteria == defaultCriteria && isDefaultFilters
    }

    var isDefaultFilters: Bool {
        true
//        filters.count == 1 && filters[0].value.isEmpty
    }

    func resetAll() {
        criteria = defaultCriteria
//        resetFilters()
        isButtonResetEnabled = false
    }
}
