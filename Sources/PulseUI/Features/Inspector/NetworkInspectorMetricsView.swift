// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

#if os(iOS) || os(macOS) || os(tvOS)

// MARK: - View

struct NetworkInspectorMetricsView: View {
    let viewModel: NetworkInspectorMetricsViewModel
    @State private var isTransctionsListShown = false

    private static let padding: CGFloat = 16

    var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack {
                    TimingView(viewModel: viewModel.timingModel, width: geo.size.width - NetworkInspectorMetricsView.padding * 2)
                        .padding(NetworkInspectorMetricsView.padding)

#if !os(tvOS)
#if !os(macOS)
                    if viewModel.transactions != nil {
                        Button(action: { isTransctionsListShown = true }) {
                            HStack {
                                Text("View All Transactions")
                                    .foregroundColor(.primary)
                                Image(systemName: "chevron.right")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                            }
                            .padding(EdgeInsets(top: 11, leading: 11, bottom: 11, trailing: 11))
                            .background(Color.secondaryFill)
                            .cornerRadius(12)
                        }
                        .padding([.leading, .trailing])
                        .padding(.top, 10)
                    }
#endif
                    if let details = viewModel.details {
                        NetworkInspectorMetricsDetailsView(viewModel: details)
                            .padding([.leading, .bottom, .trailing], NetworkInspectorMetricsView.padding)
                            .padding(.top, 20)
                    }
#endif
                }
            }
        }
        .background(links)
    }

    @ViewBuilder
    private var links: some View {
#if os(iOS)
        if let transactions = viewModel.transactions {
            NavigationLink.programmatic(isActive: $isTransctionsListShown) {
                NetworkInspectorTransactionsListView(viewModel: transactions)
            }
        }
#endif
    }
}

// MARK: - ViewModel

final class NetworkInspectorMetricsViewModel {
    let metrics: NetworkLoggerMetrics
    fileprivate let timingModel: [TimingRowSectionViewModel]
    fileprivate let details: NetworkMetricsDetailsViewModel?
#if os(iOS)
    let transactions: NetworkInspectorTransactionsListViewModel?
#endif

    init(metrics: NetworkLoggerMetrics) {
        self.metrics = metrics
        self.timingModel = makeTiming(metrics: metrics)

        self.details = metrics.transactions.first(where: {
            $0.resourceFetchType == URLSessionTaskMetrics.ResourceFetchType.networkLoad.rawValue
        }).map(NetworkMetricsDetailsViewModel.init)
#if os(iOS)
        if !metrics.transactions.isEmpty {
            self.transactions = NetworkInspectorTransactionsListViewModel(metrics: metrics)
        } else {
            self.transactions = nil
        }
#endif
    }
}

extension TimingRowSectionViewModel {
    static func make(metrics: NetworkLoggerMetrics) -> [TimingRowSectionViewModel] {
        makeTiming(metrics: metrics)
    }

    static func make(transaction: NetworkLoggerTransactionMetrics) -> [TimingRowSectionViewModel] {
        guard let startDate = transaction.fetchStartDate, let endDate = transaction.responseEndDate else {
            return []
        }
        let interval = DateInterval(start: startDate, end: endDate)
        return makeTimingRows(transaction: transaction, taskInterval: interval)
    }
}

private func makeTiming(metrics: NetworkLoggerMetrics) -> [TimingRowSectionViewModel] {
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
    let duration = to.map { $0.timeIntervalSince(from) }
    let length = duration.map { CGFloat($0 / taskInterval.duration) }
    let value = duration.map(DurationFormatter.string(from:)) ?? "–"
    return TimingRowViewModel(title: title, value: value, color: color, start: CGFloat(start), length: length ?? 1)
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

        let earliestEventDate = [
            transaction.requestStartDate,
            transaction.connectStartDate,
            transaction.domainLookupStartDate,
            transaction.responseStartDate,
            transaction.connectStartDate
        ]
            .compactMap { $0 }
            .sorted()
            .first

        if let fetchStartDate = transaction.fetchStartDate, let endDate = earliestEventDate,
           endDate.timeIntervalSince(fetchStartDate) > 0.005  {
            scheduling.append(makeRow(title: "Queued", color: .systemGray4, from: fetchStartDate, to: endDate))
        }

        if let domainLookupStartDate = transaction.domainLookupStartDate {
            connection.append(makeRow(title: "DNS", color: .systemPurple, from: domainLookupStartDate, to: transaction.domainLookupEndDate))
        }
        if let connectStartDate = transaction.connectStartDate {
            connection.append(makeRow(title: "TCP", color: .systemYellow, from: connectStartDate, to: transaction.connectEndDate))
        }
        if let secureConnectionStartDate = transaction.secureConnectionStartDate {
            connection.append(makeRow(title: "Secure", color: .systemRed, from: secureConnectionStartDate, to: transaction.secureConnectionEndDate))
        }

        if let requestStartDate = transaction.requestStartDate {
            response.append(makeRow(title: "Request", color: .systemGreen, from: requestStartDate, to: transaction.requestEndDate))
        }
        if let requestStartDate = transaction.requestStartDate, let responseStartDate = transaction.responseStartDate {
            response.append(makeRow(title: "Waiting", color: .systemGray3, from: requestStartDate, to: responseStartDate))
        }
        if let responseStartDate = transaction.responseStartDate {
            response.append(makeRow(title: "Download", color: .systemBlue, from: responseStartDate, to: transaction.responseEndDate))
        }

        if !scheduling.isEmpty {
            sections.append(TimingRowSectionViewModel(title: "Scheduling", items: scheduling))
        }
        if !connection.isEmpty {
            sections.append(TimingRowSectionViewModel(title: "Connection", items: connection))
        }
        if !response.isEmpty {
            sections.append(TimingRowSectionViewModel(title: "Response", items: response))
        }
        #warning("TODO: add other types")
    default:
        return []
    }

    return sections
}

// MARK: - Preview

#if DEBUG
struct NetworkInspectorMetricsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NetworkInspectorMetricsView(viewModel: mockModel)
                .background(Color(UXColor.systemBackground))
                .previewDisplayName("Light")
                .environment(\.colorScheme, .light)

            NetworkInspectorMetricsView(viewModel: mockModel)
                .background(Color(UXColor.systemBackground))
                .previewDisplayName("Dark")
                .environment(\.colorScheme, .dark)
                .previewLayout(.fixed(width: 500, height: 600))
        }
    }
}

private let mockModel = NetworkInspectorMetricsViewModel(
    metrics: MockDataTask.login.metrics
)
#endif

#endif
