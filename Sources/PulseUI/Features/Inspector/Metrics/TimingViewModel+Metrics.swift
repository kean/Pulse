// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

#if os(iOS) || os(macOS) || os(tvOS)

extension TimingViewModel {
    convenience init(metrics: NetworkLoggerMetrics) {
        self.init(sections: makeTimingSections(metrics: metrics))
    }

    convenience init?(transaction: NetworkLoggerTransactionMetrics, metrics: NetworkLoggerMetrics) {
        guard let startDate = transaction.fetchStartDate else {
            return nil
        }
        let endDate = transaction.responseEndDate ?? metrics.taskInterval.end
        guard endDate > startDate else {
            return nil
        }
        let interval = DateInterval(start: startDate, end: endDate)
        let sections = makeTimingRows(transaction: transaction, taskInterval: interval)
        guard !sections.isEmpty else {
            return nil
        }
        self.init(sections: sections)
    }
}

private func makeTimingSections(metrics: NetworkLoggerMetrics) -> [TimingRowSectionViewModel] {
    let taskInterval = metrics.taskInterval

    var sections = [TimingRowSectionViewModel]()

    var currentURL: URL?

    for transaction in metrics.transactions {
        let rows = makeTimingRows(transaction: transaction, taskInterval: taskInterval)
        guard !rows.isEmpty else {
            continue
        }

        if metrics.redirectCount > 0, let url = transaction.request?.url, currentURL != url {
            currentURL = url
            sections.append(TimingRowSectionViewModel(title: url.absoluteString, items: [], isHeader: true))
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

private func makeTimingRows(transaction: NetworkLoggerTransactionMetrics, taskInterval: DateInterval) -> [TimingRowSectionViewModel] {
    var sections = [TimingRowSectionViewModel]()

    func makeRow(title: String, color: UXColor, from: Date, to: Date?) -> TimingRowViewModel {
        _makeRow(title: title, color: color, from: from, to: to, taskInterval: taskInterval)
    }

    guard let fetchType = URLSessionTaskMetrics.ResourceFetchType(rawValue: transaction.resourceFetchType) else {
        return []
    }

    switch fetchType {
    case .localCache:
        if let requestStartDate = transaction.requestStartDate,
           let responseEndDate = transaction.responseEndDate {
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

        let earliestEventDate = transaction.domainLookupStartDate ?? transaction.connectStartDate ?? transaction.requestStartDate

        // Scheduling Section

        if let fetchStartDate = transaction.fetchStartDate, let endDate = earliestEventDate,
           endDate.timeIntervalSince(fetchStartDate) > 0.001  {
            scheduling.append(makeRow(title: "Queued", color: .systemGray4, from: fetchStartDate, to: endDate))
        }

        // Connection Section

        if let domainLookupStartDate = transaction.domainLookupStartDate {
            connection.append(makeRow(title: "DNS", color: .systemPurple, from: domainLookupStartDate, to: transaction.domainLookupEndDate))
        }
        if let connectStartDate = transaction.connectStartDate {
            connection.append(makeRow(title: "TCP", color: .systemYellow, from: connectStartDate, to: transaction.connectEndDate))
        }
        if let secureConnectionStartDate = transaction.secureConnectionStartDate {
            connection.append(makeRow(title: "Secure", color: .systemRed, from: secureConnectionStartDate, to: transaction.secureConnectionEndDate))
        }

        // Response Section

        let latestPreviousEndDate = transaction.requestEndDate ?? transaction.connectEndDate ?? transaction.domainLookupEndDate ?? transaction.fetchStartDate

        if let requestStartDate = transaction.requestStartDate {
            response.append(makeRow(title: "Request", color: .systemGreen, from: requestStartDate, to: transaction.requestEndDate))
        }
        if let requestEndDate = latestPreviousEndDate, let responseStartDate = transaction.responseStartDate {
            response.append(makeRow(title: "Waiting", color: .systemGray3, from: requestEndDate, to: responseStartDate))
        }
        if let responseStartDate = transaction.responseStartDate {
            response.append(makeRow(title: "Download", color: .systemBlue, from: responseStartDate, to: transaction.responseEndDate))
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

#endif
