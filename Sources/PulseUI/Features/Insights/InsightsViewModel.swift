// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS)

import Foundation
import Combine
import Pulse
import SwiftUI
import CoreData
import Charts

final class InsightsViewModel: ObservableObject, ConsoleDataSourceDelegate {
    @Published private(set) var insights = NetworkLoggerInsights([])

    var isViewVisible = false {
        didSet {
            if isViewVisible {
                resetDataSource()
            } else {
                dataSource = nil
            }
        }
    }

    var medianDuration: String {
        guard let median = insights.duration.median else { return "–" }
        return DurationFormatter.string(from: median, isPrecise: false)
    }

    var durationRange: String {
        guard let min = insights.duration.minimum,
              let max = insights.duration.maximum else {
            return "–"
        }
        if min == max {
            return DurationFormatter.string(from: min, isPrecise: false)
        }
        return "\(DurationFormatter.string(from: min, isPrecise: false)) – \(DurationFormatter.string(from: max, isPrecise: false))"
    }

    @available(iOS 16, macOS 13, *)
    struct Bar: Identifiable {
        var id: Int { index }

        let index: Int
        let range: ChartBinRange<TimeInterval>
        var count: Int
    }

    @available(iOS 16, macOS 13, *)
    var durationBars: [Bar] {
        let values = insights.duration.values.map { min(3.4, $0) }
        let bins = NumberBins(data: values, desiredCount: 30)
        let groups = Dictionary(grouping: values, by: bins.index)
        return groups.map { key, values in
            Bar(index: key, range: bins[key], count: values.count)
        }
    }

    weak var consoleViewModel: ConsoleViewModel?

    private let store: LoggerStore
    private var dataSource: ConsoleDataSource?

    init(store: LoggerStore) {
        self.store = store
    }

    // MARK: Focused Views

#if os(iOS)
    func makeSlowestRequestsViewModel() -> ConsoleViewModel {
        makeDestinationListViewModel {
            $0.listViewModel.options.taskSortBy = .duration
        }
    }

    func makeRequestsWithDedirectsViewModel() -> ConsoleViewModel {
        makeDestinationListViewModel {
            $0.searchCriteriaViewModel.criteria.network.networking.isRedirect = true
        }
    }

    func makeFailedRequestsViewModel() -> ConsoleViewModel {
        makeDestinationListViewModel {
            $0.searchCriteriaViewModel.isOnlyErrors = true
        }
    }

    private func makeDestinationListViewModel(_ configure: (ConsoleViewModel) -> Void) -> ConsoleViewModel {
        guard let sourceViewModel = consoleViewModel else { fatalError() }
        let viewModel = ConsoleViewModel(store: sourceViewModel.store)
        viewModel.mode = .tasks
#warning("pass criteria on macOS?")
        configure(viewModel)
        return viewModel
    }
#else
#warning("figure out how to remove focus")
    func focusOnSlowestRequests() {
        consoleViewModel?.mode = .tasks
        consoleViewModel?.listViewModel.options.taskSortBy = .duration
    }
#endif

    // MARK: DataSource

    private func resetDataSource() {
        guard isViewVisible else { return }

        dataSource = ConsoleDataSource(store: store, mode: .tasks)
        dataSource?.delegate = self
        dataSource?.refresh()

#if os(iOS)
        dataSource?.setPredicate(criteria: ConsoleSearchCriteria(), focus: nil, isOnlyErrors: false)
        dataSource?.refresh()
#else
        if let viewModel = consoleViewModel?.searchCriteriaViewModel {
            dataSource?.bind(viewModel)
        } else {
            dataSource?.refresh()
        }
#endif
    }

    private var tasks: [NetworkTaskEntity] {
        (dataSource?.entities as? [NetworkTaskEntity]) ?? []
    }

    // MARK: ConsoleDataSourceDelegate

    func dataSourceDidRefresh(_ dataSource: ConsoleDataSource) {
        insights = NetworkLoggerInsights(tasks)
    }

    func dataSource(_ dataSource: ConsoleDataSource, didUpdateWith diff: CollectionDifference<NSManagedObjectID>?) {
        withAnimation {
            if let diff = diff {
                for change in diff {
                    switch change {
                    case .insert(_, let objectID, _):
                        if let task = (try? store.viewContext.existingObject(with: objectID)) as? NetworkTaskEntity, task.state != .pending {
                            insights.insert(task)
                        }
                    case .remove:
                        break
                    }
                }
            } else {
                insights = NetworkLoggerInsights(tasks)
            }
        }
    }
}

#endif
