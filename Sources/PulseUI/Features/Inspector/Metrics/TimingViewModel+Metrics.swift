// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

extension TimingViewModel {
    convenience init(task: NetworkTaskEntity) {
        self.init(sections: makeTimingSections(task: task))
    }

    convenience init?(transaction: NetworkTransactionMetricsEntity, task: NetworkTaskEntity) {
        guard let interval = task.taskInterval else { // Anchor to task
            return nil
        }
        let sections = makeTimingRows(transaction: transaction, taskInterval: interval)
        guard !sections.isEmpty else {
            return nil
        }
        self.init(sections: sections)
    }
}

private func makeTimingSections(task: NetworkTaskEntity) -> [TimingRowSectionViewModel] {
    guard let taskInterval = task.taskInterval else {
        return []
    }

    var sections = [TimingRowSectionViewModel]()

    var currentURL: String?

    for transaction in task.orderedTransactions {
        let rows = makeTimingRows(transaction: transaction, taskInterval: taskInterval)
        guard !rows.isEmpty else {
            continue
        }

        if task.redirectCount > 0, let url = transaction.request.url, currentURL != url {
            currentURL = url
            sections.append(TimingRowSectionViewModel(title: url, items: [], isHeader: true))
        }

        sections += rows
    }

    sections.append(TimingRowSectionViewModel(title: "Total", items: [
        _makeRow(title: "Total", color: .systemGray2, from: taskInterval.start, to: taskInterval.end, taskInterval: taskInterval)
    ]))

    return sections
}

private func _makeRow(title: String, color: UXColor, from: Date, to: Date?, taskInterval: DateInterval) -> TimingRowViewModel {
    let start = CGFloat(from.timeIntervalSince(taskInterval.start) / taskInterval.duration)
    let to = to ?? taskInterval.end
    let duration = to.timeIntervalSince(from)
    let length = CGFloat(duration / taskInterval.duration)
    let value = DurationFormatter.string(from: duration)
    return TimingRowViewModel(title: title, value: value, color: color, start: CGFloat(start), length: length)
}

private func makeTimingRows(transaction: NetworkTransactionMetricsEntity, taskInterval: DateInterval) -> [TimingRowSectionViewModel] {
    var sections = [TimingRowSectionViewModel]()

    func makeRow(title: String, color: UXColor, from: Date, to: Date?) -> TimingRowViewModel {
        _makeRow(title: title, color: color, from: from, to: to, taskInterval: taskInterval)
    }

    let timing = transaction.timing

    switch transaction.fetchType {
    case .localCache:
        if let requestStartDate = timing.requestStartDate,
           let responseEndDate = timing.responseEndDate {
            let section = TimingRowSectionViewModel(
                title: "Local Cache",
                items: [
                    makeRow(title: "Lookup", color: .systemTeal, from: requestStartDate, to: responseEndDate)
                ])
            sections.append(section)
        }
    case .networkLoad:
        var scheduling: [TimingRowViewModel] = []
        var connection: [TimingRowViewModel] = []
        var response: [TimingRowViewModel] = []

        let earliestEventDate = timing.domainLookupStartDate ?? timing.connectStartDate ?? timing.requestStartDate

        // Scheduling Section

        if let fetchStartDate = timing.fetchStartDate, let endDate = earliestEventDate,
           endDate.timeIntervalSince(fetchStartDate) > 0.001  {
            scheduling.append(makeRow(title: "Queued", color: .systemGray4, from: fetchStartDate, to: endDate))
        }

        // Connection Section

        if let domainLookupStartDate = timing.domainLookupStartDate {
            connection.append(makeRow(title: "DNS", color: .systemPurple, from: domainLookupStartDate, to: timing.domainLookupEndDate))
        }
        if let connectStartDate = timing.connectStartDate {
            connection.append(makeRow(title: "TCP", color: .systemYellow, from: connectStartDate, to: timing.connectEndDate))
        }
        if let secureConnectionStartDate = timing.secureConnectionStartDate {
            connection.append(makeRow(title: "Secure", color: .systemRed, from: secureConnectionStartDate, to: timing.secureConnectionEndDate))
        }

        // Response Section

        let latestPreviousEndDate = timing.requestEndDate ?? timing.connectEndDate ?? timing.domainLookupEndDate ?? timing.fetchStartDate

        if let requestStartDate = timing.requestStartDate, let requestEndDate = timing.requestEndDate {
            response.append(makeRow(title: "Request", color: .systemGreen, from: requestStartDate, to: requestEndDate))
        }
        if let requestEndDate = latestPreviousEndDate, let responseStartDate = timing.responseStartDate {
            response.append(makeRow(title: "Waiting", color: .systemGray3, from: requestEndDate, to: responseStartDate))
        }
        if let responseStartDate = timing.responseStartDate {
            response.append(makeRow(title: "Download", color: .systemBlue, from: responseStartDate, to: timing.responseEndDate))
        }

        // Commit sections

        if !scheduling.isEmpty {
            sections.append(TimingRowSectionViewModel(title: "Scheduling", items: scheduling))
        }
        if !connection.isEmpty {
            sections.append(TimingRowSectionViewModel(title: "Connection", items: connection))
        }
        if !response.isEmpty {
            sections.append(TimingRowSectionViewModel(title: "Response", items: response))
        }
    default:
        return []
    }

    return sections
}

extension URLSessionTaskMetrics.ResourceFetchType {
    var title: String {
        switch self {
        case .networkLoad: return "Network Load"
        case .localCache: return "Cache Lookup"
        case .serverPush: return "Server Push"
        case .unknown: return "Unknown Fetch Type"
        default: return "Unknown Fetch Type"
        }
    }
}
