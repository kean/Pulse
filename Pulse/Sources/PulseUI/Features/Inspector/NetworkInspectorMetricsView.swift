// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

#if os(iOS) || os(macOS) || os(tvOS)

// MARK: - View

@available(iOS 13.0, tvOS 14.0, *)
struct NetworkInspectorMetricsView: View {
    let model: NetworkInspectorMetricsViewModel

    private static let padding: CGFloat = 16

    var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack {
                    TimingView(model: model.timingModel, width: geo.size.width - NetworkInspectorMetricsView.padding * 2)
                        .padding(NetworkInspectorMetricsView.padding)
                    Spacer(minLength: 32)

                    #if !os(tvOS)
                    if let details = model.details {
                        NetworkInspectorMetricsDetailsView(model: details)
                            .padding([.leading, .bottom, .trailing], NetworkInspectorMetricsView.padding)
                    }
                    #endif
                }
            }
        }
    }
}

// MARK: - ViewModel

@available(iOS 13.0, tvOS 14.0, watchOS 6, *)
final class NetworkInspectorMetricsViewModel {
    let metrics: NetworkLoggerMetrics
    fileprivate let timingModel: [TimingRowSectionViewModel]
    fileprivate let details: NetworkMetricsDetailsViewModel?

    init(metrics: NetworkLoggerMetrics) {
        self.metrics = metrics
        self.timingModel = makeTiming(metrics: metrics)

        self.details = metrics.transactions.first(where: {
            $0.resourceFetchType == URLSessionTaskMetrics.ResourceFetchType.networkLoad.rawValue
        }).map(NetworkMetricsDetailsViewModel.init)
    }
}

@available(iOS 13.0, tvOS 14.0, *)
private func makeTiming(metrics: NetworkLoggerMetrics) -> [TimingRowSectionViewModel] {
    let taskInterval = metrics.taskInterval

    var sections = [TimingRowSectionViewModel]()

    func makeRow(title: String, color: UXColor, from: Date, to: Date?) -> TimingRowViewModel {
        let start = CGFloat(from.timeIntervalSince(taskInterval.start) / taskInterval.duration)
        let duration = to.map { $0.timeIntervalSince(from) }
        let length = duration.map { CGFloat($0 / taskInterval.duration) }
        let value = duration.map(DurationFormatter.string(from:)) ?? "–"
        return TimingRowViewModel(title: title, value: value, color: color, start: CGFloat(start), length: length ?? 1)
    }

    for transaction in metrics.transactions {
        guard let fetchType = URLSessionTaskMetrics.ResourceFetchType(rawValue: transaction.resourceFetchType) else {
            continue
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

            let hasCacheLookup = metrics.transactions.contains(where: {
                $0.resourceFetchType == URLSessionTaskMetrics.ResourceFetchType.localCache.rawValue
            })
            if !hasCacheLookup, let fetchStartDate = transaction.fetchStartDate, let endDate = earliestEventDate {
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
        default:
            continue
        }
    }

    sections.append(TimingRowSectionViewModel(title: "Total", items: [
        makeRow(title: "Total", color: .systemGray2, from: taskInterval.start, to: taskInterval.end)
    ]))

    return sections
}

// MARK: - Preview

#if DEBUG
@available(iOS 13.0, tvOS 14.0, *)
struct NetworkInspectorMetricsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NetworkInspectorMetricsView(model: mockModel)
                .background(Color(UXColor.systemBackground))
                .previewDisplayName("Light")
                .environment(\.colorScheme, .light)
            
            NetworkInspectorMetricsView(model: mockModel)
                .background(Color(UXColor.systemBackground))
                .previewDisplayName("Dark")
                .environment(\.colorScheme, .dark)
        }
    }
}

@available(iOS 13.0, tvOS 14.0, *)
private let mockModel = NetworkInspectorMetricsViewModel(
    metrics: MockDataTask.login.metrics
)
#endif

#endif
