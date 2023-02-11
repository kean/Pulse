// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import SwiftUI
import CoreData
import Pulse
import Combine

final class ConsoleTableViewModel: ObservableObject, ConsoleDataSourceDelegate {
    @Published private(set) var entities: [NSManagedObject] = []

    var isViewVisible = false {
        didSet {
            if isViewVisible {
                resetDataSource()
            } else {
                dataSource = nil
            }
        }
    }

    var mode: ConsoleMode = .all {
        didSet {
            sortDescriptors = []
            resetDataSource()
        }
    }

    private var sortDescriptors: [NSSortDescriptor] = []

    private let store: LoggerStore
    private let context: ConsoleContext
    private let searchCriteriaViewModel: ConsoleSearchCriteriaViewModel

    private var dataSource: ConsoleDataSource?

    init(store: LoggerStore, context: ConsoleContext, criteria: ConsoleSearchCriteriaViewModel) {
        self.store = store
        self.context = context
        self.searchCriteriaViewModel = criteria
    }

    // MARK: DataSource

    private func resetDataSource() {
        guard isViewVisible else { return }

        dataSource = ConsoleDataSource(store: store, context: context, mode: mode)
        if !sortDescriptors.isEmpty {
            dataSource?.sortDescriptors = sortDescriptors
        }
        dataSource?.delegate = self
        dataSource?.bind(searchCriteriaViewModel)
    }

    func sort(using sortDescriptors: [NSSortDescriptor]) {
        self.sortDescriptors = sortDescriptors
        dataSource?.sortDescriptors = sortDescriptors
        dataSource?.refresh()
    }

    // MARK: ConsoleDataSourceDelegate

    func dataSourceDidRefresh(_ dataSource: ConsoleDataSource) {
        entities = dataSource.entities
    }

    func dataSource(_ dataSource: ConsoleDataSource, didUpdateWith diff: CollectionDifference<NSManagedObjectID>?) {
        withAnimation {
            entities = dataSource.entities
        }
    }
}

#endif
