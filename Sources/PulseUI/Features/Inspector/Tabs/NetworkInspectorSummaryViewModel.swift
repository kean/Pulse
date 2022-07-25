// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

final class NetworkInspectorSummaryViewModel: ObservableObject {
    private let summary: NetworkLoggerSummary

    @Published var isErrorRawLinkActive = false
    @Published var isRequestRawLinkActive = false
    @Published var isOriginalRequestHeadersLinkActive = false
    @Published var isOriginalQueryItemsLinkActive = false
    @Published var isCurrentRequestHeadersLinkActive = false
    @Published var isCurrentQueryItemsLinkActive = false
    @Published var isResponseRawLinkActive = false
    @Published var isResponseHeadearsRawLinkActive = false

    var progress: ProgressViewModel { summary.progress }

    #warning("TODO: inject request")
    init(summary: NetworkLoggerSummary) {
        self.summary = summary
    }

    var tintColor: Color {
        switch summary.state {
        case .pending: return .orange
        case .success: return .green
        case .failure: return .red
        }
    }

    var state: LoggerNetworkRequestEntity.State {
        summary.state
    }

    // MARK: - Transfer

    var transferModel: NetworkInspectorTransferInfoViewModel? {
        summary.metrics.flatMap { NetworkInspectorTransferInfoViewModel(metrics: $0, taskType: summary.taskType ?? .dataTask) }
    }

    // MARK: - Summary

    var summaryModel: KeyValueSectionViewModel {
        var items: [(String, String?)] = [
            ("URL", summary.originalRequest?.url?.absoluteString ?? "–"),
            ("Method", summary.originalRequest?.httpMethod ?? "–")
        ]

        if summary.state == .failure || summary.state == .success {
            items.append(("Status Code", summary.response?.statusCode.map(StatusCodeFormatter.string) ?? "–"))

            if let metrics = summary.metrics {
                items.append(("Duration", DurationFormatter.string(from: metrics.taskInterval.duration)))
            }
            items.append(("Source", summary.isFromCache ? "Cache" : "Network"))
        }

        var title = summary.taskType?.urlSessionTaskClassName ?? "Summary"
        #if os(watchOS)
        title = title.replacingOccurrences(of: "URLSession", with: "")
        #endif
        return KeyValueSectionViewModel(title: title, color: tintColor, items: items)
    }

    var errorModel: KeyValueSectionViewModel? {
        guard let error = summary.error else { return nil }
        return KeyValueSectionViewModel.makeErrorDetails(for: error) { [unowned self] in
            isErrorRawLinkActive = true
        }
    }

    // MARK: - Request (Original)

    var originalRequestSummary: KeyValueSectionViewModel? {
        summary.originalRequest.map(KeyValueSectionViewModel.makeSummary)
    }

    var originalRequestQueryItems: KeyValueSectionViewModel? {
        summary.originalRequest?.url.flatMap {
            KeyValueSectionViewModel.makeQueryItems(for: $0) { [unowned self] in
                self.isOriginalQueryItemsLinkActive = true
            }
        }
    }

    var originalRequestParameters: KeyValueSectionViewModel? {
        summary.originalRequest.map(KeyValueSectionViewModel.makeParameters)
    }

    var originalRequestHeaders: KeyValueSectionViewModel {
        KeyValueSectionViewModel.makeRequestHeaders(for: summary.originalRequest?.headers ?? [:]) { [unowned self] in
            self.isOriginalRequestHeadersLinkActive = true
        }
    }

    var requestBodySection: KeyValueSectionViewModel {
        guard summary.requestBodyKey != nil, summary.requestBodySize > 0 else {
            return KeyValueSectionViewModel(title: "Request Body", color: .blue)
        }
        let contentType = summary.originalRequest?.headers.first(where: { $0.key == "Content-Type" })?.value ?? "–"
        return KeyValueSectionViewModel(
            title: "Request Body",
            color: .blue,
            action: ActionViewModel(
                action: { [unowned self] in isRequestRawLinkActive = true },
                title: "View"
            ),
            items: [
                ("Content-Type", contentType),
                ("Size", ByteCountFormatter.string(fromByteCount: summary.requestBodySize, countStyle: .file))
            ]
        )
    }

    // MARK: - Request (Current)

    var currentRequestSummary: KeyValueSectionViewModel? {
        summary.currentRequest.map(KeyValueSectionViewModel.makeSummary)
    }

    var currentRequestQueryItems: KeyValueSectionViewModel? {
        summary.originalRequest?.url.flatMap {
            KeyValueSectionViewModel.makeQueryItems(for: $0) { [unowned self] in
                self.isCurrentQueryItemsLinkActive = true
            }
        }
    }

    var currentRequestParameters: KeyValueSectionViewModel? {
        summary.currentRequest.map(KeyValueSectionViewModel.makeParameters)
    }

    var currentRequestHeaders: KeyValueSectionViewModel {
        KeyValueSectionViewModel.makeRequestHeaders(for: summary.currentRequest?.headers ?? [:]) { [unowned self] in
            self.isCurrentRequestHeadersLinkActive = true
        }
    }

    var currentRequestBodySection: KeyValueSectionViewModel {
        guard summary.requestBodyKey != nil, summary.requestBodySize > 0 else {
            return KeyValueSectionViewModel(title: "Request Body", color: .blue)
        }
        let contentType = summary.currentRequest?.headers.first(where: { $0.key == "Content-Type" })?.value ?? "–"
        return KeyValueSectionViewModel(
            title: "Request Body",
            color: .blue,
            action: ActionViewModel(
                action: { [unowned self] in isRequestRawLinkActive = true },
                title: "View"
            ),
            items: [
                ("Content-Type", contentType),
                ("Size", ByteCountFormatter.string(fromByteCount: summary.requestBodySize, countStyle: .file))
            ]
        )
    }

    // MARK: - Response

    var responseSummary: KeyValueSectionViewModel? {
        summary.response.map(KeyValueSectionViewModel.makeSummary)
    }

    var responseHeaders: KeyValueSectionViewModel {
        KeyValueSectionViewModel.makeResponseHeaders(for: summary.response?.headers ?? [:]) { [unowned self] in
            self.isResponseHeadearsRawLinkActive = true
        }
    }

    var responseBodySection: KeyValueSectionViewModel {
        if summary.taskType == .downloadTask, summary.responseBodySize > 0 {
            return KeyValueSectionViewModel(title: "Response Body", color: .indigo, items: [
                ("Download Size", ByteCountFormatter.string(fromByteCount: summary.responseBodySize, countStyle: .file))
            ])
        }
        guard summary.responseBodyKey != nil, summary.responseBodySize > 0 else {
            return KeyValueSectionViewModel(title: "Response Body", color: .indigo)
        }
        let contentType = summary.response?.headers.first(where: { $0.key == "Content-Type" })?.value ?? "–"
        let size = ByteCountFormatter.string(fromByteCount: summary.responseBodySize, countStyle: .file)
        return KeyValueSectionViewModel(
            title: "Response Body",
            color: .indigo,
            action: ActionViewModel(
                action: { [unowned self] in isResponseRawLinkActive = true },
                title: "View"
            ),
            items: [
                ("Content-Type", contentType),
                ("Size", summary.isFromCache ? size + " (from cache)": size)
            ]
        )
    }

    // MARK: - Timings

    var timingDetailsModel: KeyValueSectionViewModel? {
        guard let metrics = summary.metrics else { return nil }
        return KeyValueSectionViewModel(title: "Timing", color: .orange, items: [
            ("Start Date", dateFormatter.string(from: metrics.taskInterval.start)),
            ("End Date", dateFormatter.string(from: metrics.taskInterval.end)),
            ("Duration", DurationFormatter.string(from: metrics.taskInterval.duration)),
            ("Redirect Count", metrics.redirectCount.description)
        ])
    }

    // MARK: - Destinations

    var requestBodyViewModel: NetworkInspectorResponseViewModel {
        let summary = self.summary
        return NetworkInspectorResponseViewModel(title: "Request", data: summary.requestBody ?? Data())
    }

    var responseBodyViewModel: NetworkInspectorResponseViewModel {
        let summary = self.summary
        return NetworkInspectorResponseViewModel(title: "Response", data: summary.responseBody ?? Data())
    }
}

// MARK: - Private

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    return formatter
}()
