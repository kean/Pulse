// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

final class NetworkInspectorSummaryViewModel: ObservableObject {
    private let summary: NetworkLoggerSummary

    @Published var isErrorRawLinkActive = false
    @Published var isRequestRawLinkActive = false
    @Published var isRequestHeadersLinkActive = false
    @Published var isResponseRawLinkActive = false
    @Published var isResponseHeadearsRawLinkActive = false

    init(summary: NetworkLoggerSummary) {
        self.summary = summary
    }

    private var tintColor: Color {
        switch summary.state {
        case .pending: return .orange
        case .success: return .green
        case .failure: return .red
        }
    }

    // MARK: - Transfer

    var transferModel: NetworkInspectorTransferInfoViewModel? {
        summary.metrics.flatMap(NetworkInspectorTransferInfoViewModel.init)
    }

    // MARK: - Summary

    var summaryModel: KeyValueSectionViewModel {
        var items: [(String, String?)] = [
            ("Status Code", summary.response?.statusCode.map(StatusCodeFormatter.string) ?? "–"),
            ("Method", summary.originalRequest?.httpMethod ?? "–"),
            ("URL", summary.originalRequest?.url?.absoluteString ?? "–"),
            ("Domain", summary.originalRequest?.url?.host ?? "–")
        ]
        if summary.originalRequest?.url != summary.currentRequest?.url && summary.currentRequest?.url != nil {
            items.append(("Redirect", summary.currentRequest?.url?.absoluteString ?? "–"))
        }

        return KeyValueSectionViewModel(title: "Summary", color: tintColor, items: items)
    }

    var errorModel: KeyValueSectionViewModel? {
        guard let error = summary.error else { return nil }
        return KeyValueSectionViewModel.makeErrorDetails(
            for: error,
            action: { [unowned self] in isErrorRawLinkActive = true }
        )
    }

    // MARK: - Request

    var requestSummary: KeyValueSectionViewModel? {
        summary.originalRequest.map(KeyValueSectionViewModel.makeSummary)
    }

    var requestParameters: KeyValueSectionViewModel? {
        summary.originalRequest.map(KeyValueSectionViewModel.makeParameters)
    }

    var requestHeaders: KeyValueSectionViewModel {
        KeyValueSectionViewModel.makeRequestHeaders(
            for: summary.originalRequest?.headers ?? [:],
            action: { [unowned self] in self.isRequestHeadersLinkActive = true }
        )
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

    // MARK: - Response

    var responseSummary: KeyValueSectionViewModel? {
        summary.response.map(KeyValueSectionViewModel.makeSummary)
    }

    var responseHeaders: KeyValueSectionViewModel {
        KeyValueSectionViewModel.makeRequestHeaders(
            for: summary.response?.headers ?? [:],
            action: { [unowned self] in self.isResponseHeadearsRawLinkActive = true }
        )
    }

    var responseBodySection: KeyValueSectionViewModel {
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
            ("Start Date", isoFormatter.string(from: metrics.taskInterval.start)),
            ("End Date", isoFormatter.string(from: metrics.taskInterval.end)),
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

private let isoFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()
