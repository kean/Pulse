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

    private let store: LoggerStore
    private let context: ConsoleContext
    private let searchCriteriaViewModel: ConsoleSearchCriteriaViewModel

    private var dataSource: ConsoleDataSource?

    init(store: LoggerStore, context: ConsoleContext, criteria: ConsoleSearchCriteriaViewModel) {
        self.store = store
        self.context = context
        self.searchCriteriaViewModel = criteria
    }

    // MARK: - Accessing Data

    func topSlowestRequests() -> [NetworkTaskEntity] {
        tasks(with: insights.duration.topSlowestRequests.map { $0.0 })
    }

    func requestsWithRedirects() -> [NetworkTaskEntity] {
        tasks(with: Array(insights.redirects.taskIds))
            .sorted(by: { $0.createdAt > $1.createdAt })
    }

    func failedRequests() -> [NetworkTaskEntity] {
        tasks(with: Array(insights.failures.taskIds))
            .sorted(by: { $0.createdAt > $1.createdAt })
    }

    private func tasks(with ids: [NSManagedObjectID]) -> [NetworkTaskEntity] {
        ids.compactMap { (try? store.viewContext.existingObject(with: $0)) as? NetworkTaskEntity }
    }

    // MARK: DataSource

    private func resetDataSource() {
        guard isViewVisible else { return }

        dataSource = ConsoleDataSource(store: store, context: context, mode: .tasks)
        dataSource?.delegate = self
        dataSource?.bind(searchCriteriaViewModel)
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
