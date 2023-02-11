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

final class InsightsViewModel: ObservableObject {
    let insights: NetworkLoggerInsights
    private var cancellable: AnyCancellable?

    private let store: LoggerStore

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

#warning("add ConsoleDataStore")
    init(store: LoggerStore, insights: NetworkLoggerInsights = .init([])) {
        self.store = store
        self.insights = insights
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

#warning("remove")
    private func tasks(with ids: [UUID]) -> [NetworkTaskEntity] {
        let request = NSFetchRequest<NetworkTaskEntity>(entityName: "\(NetworkTaskEntity.self)")
        request.fetchLimit = ids.count
        request.predicate = NSPredicate(format: "taskId IN %@", ids)

        return (try? store.viewContext.fetch(request)) ?? []
    }
}

#endif
