// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine

final class NetworkInspectorSummaryViewModel: ObservableObject {
    @Published var isErrorRawLinkActive = false
    @Published var isRequestRawLinkActive = false
    @Published var isOriginalRequestHeadersLinkActive = false
    @Published var isOriginalQueryItemsLinkActive = false
    @Published var isCurrentRequestHeadersLinkActive = false
    @Published var isCurrentQueryItemsLinkActive = false
    @Published var isResponseRawLinkActive = false
    @Published var isResponseHeadearsRawLinkActive = false

    private(set) lazy var _progressViewModel = ProgressViewModel(request: request)

    private let request: LoggerNetworkRequestEntity
    private var cancellable: AnyCancellable?

    init(request: LoggerNetworkRequestEntity) {
        self.request = request
        cancellable = request.objectWillChange.sink { [weak self] in self?.refresh() }
    }

    private func refresh() {
        withAnimation { objectWillChange.send() }
    }

    var tintColor: Color {
        switch request.state {
        case .pending: return .orange
        case .success: return .green
        case .failure: return .red
        }
    }

    var statusImageName: String {
        switch request.state {
        case .pending: return "clock.fill"
        case .success: return "checkmark.circle.fill"
        case .failure: return "exclamationmark.octagon.fill"
        }
    }

    // MARK: - Header

    var transferViewModel: NetworkInspectorTransferInfoViewModel? {
        request.metrics.map {
            NetworkInspectorTransferInfoViewModel(metrics: $0, taskType: request.taskType ?? .dataTask)
        }
    }

    var progressViewModel: ProgressViewModel? {
        guard request.state == .pending else { return nil }
        return _progressViewModel
    }

    // MARK: - Summary

    var summaryViewModel: KeyValueSectionViewModel {
        var items: [(String, String?)] = [
            ("URL", request.url ?? "–"),
            ("Method", request.httpMethod ?? "–")
        ]

        if request.state == .failure || request.state == .success {
            items.append(("Status Code", StatusCodeFormatter.string(for: request.statusCode)))
            if request.duration > 0 {
                items.append(("Duration", DurationFormatter.string(from: request.duration)))
            }
            items.append(("Source", request.isFromCache ? "Cache" : "Network"))
        }

        var title = request.taskType?.urlSessionTaskClassName ?? "Summary"
        #if os(watchOS)
        title = title.replacingOccurrences(of: "URLSession", with: "")
        #endif
        return KeyValueSectionViewModel(title: title, color: tintColor, items: items)
    }

    var errorModel: KeyValueSectionViewModel? {
        guard let error = request.error else { return nil }
        return KeyValueSectionViewModel.makeErrorDetails(for: error) { [unowned self] in
            isErrorRawLinkActive = true
        }
    }

    // MARK: - Request (Original)

    var originalRequestSummary: KeyValueSectionViewModel? {
        KeyValueSectionViewModel.makeSummary(for: request.originalRequest)
    }

#if os(iOS) || os(macOS)
    var originalRequestQueryItems: KeyValueSectionViewModel? {
        request.originalRequest.url.flatMap(URL.init).flatMap {
            KeyValueSectionViewModel.makeQueryItems(for: $0) { [unowned self] in
                self.isOriginalQueryItemsLinkActive = true
            }
        }
    }
#endif

    var originalRequestParameters: KeyValueSectionViewModel {
        KeyValueSectionViewModel.makeParameters(for: request.originalRequest)
    }

    var originalRequestHeaders: KeyValueSectionViewModel {
        KeyValueSectionViewModel.makeRequestHeaders(for: request.originalRequest.headers) { [unowned self] in
            self.isOriginalRequestHeadersLinkActive = true
        }
    }

    var requestBodySection: KeyValueSectionViewModel {
        guard request.requestBodySize > 0 else {
            return KeyValueSectionViewModel(title: "Request Body", color: .blue)
        }
        let contentType = request.originalRequest.headers.first(where: { $0.key == "Content-Type" })?.value ?? "–"
        return KeyValueSectionViewModel(
            title: "Request Body",
            color: .blue,
            action: ActionViewModel(
                action: { [unowned self] in isRequestRawLinkActive = true },
                title: "View"
            ),
            items: [
                ("Content-Type", contentType),
                ("Size", ByteCountFormatter.string(fromByteCount: request.requestBodySize))
            ]
        )
    }

    // MARK: - Request (Current)

    var currentRequestSummary: KeyValueSectionViewModel? {
        request.currentRequest.map(KeyValueSectionViewModel.makeSummary)
    }

#if os(iOS) || os(macOS)
    var currentRequestQueryItems: KeyValueSectionViewModel? {
        request.originalRequest.url.flatMap(URL.init).flatMap {
            KeyValueSectionViewModel.makeQueryItems(for: $0) { [unowned self] in
                self.isCurrentQueryItemsLinkActive = true
            }
        }
    }
#endif

    var currentRequestParameters: KeyValueSectionViewModel? {
        request.currentRequest.map(KeyValueSectionViewModel.makeParameters)
    }

    var currentRequestHeaders: KeyValueSectionViewModel {
        KeyValueSectionViewModel.makeRequestHeaders(for: request.currentRequest?.headers ?? [:]) { [unowned self] in
            self.isCurrentRequestHeadersLinkActive = true
        }
    }

    var currentRequestBodySection: KeyValueSectionViewModel {
        guard request.requestBodySize > 0 else {
            return KeyValueSectionViewModel(title: "Request Body", color: .blue)
        }
        let contentType = request.currentRequest?.headers.first(where: { $0.key == "Content-Type" })?.value ?? "–"
        return KeyValueSectionViewModel(
            title: "Request Body",
            color: .blue,
            action: ActionViewModel(
                action: { [unowned self] in isRequestRawLinkActive = true },
                title: "View"
            ),
            items: [
                ("Content-Type", contentType),
                ("Size", ByteCountFormatter.string(fromByteCount: request.requestBodySize))
            ]
        )
    }

    // MARK: - Response

    var responseSummary: KeyValueSectionViewModel? {
        request.response.map(KeyValueSectionViewModel.makeSummary)
    }

    var responseHeaders: KeyValueSectionViewModel {
        KeyValueSectionViewModel.makeResponseHeaders(for: request.response?.headers ?? [:]) { [unowned self] in
            self.isResponseHeadearsRawLinkActive = true
        }
    }

    var responseBodySection: KeyValueSectionViewModel {
        if request.taskType == .downloadTask, request.responseBodySize > 0 {
            return KeyValueSectionViewModel(title: "Response Body", color: .indigo, items: [
                ("Download Size", ByteCountFormatter.string(fromByteCount: request.responseBodySize))
            ])
        }
        guard request.responseBodySize > 0 else {
            return KeyValueSectionViewModel(title: "Response Body", color: .indigo)
        }
        let size = ByteCountFormatter.string(fromByteCount: request.responseBodySize)
        return KeyValueSectionViewModel(
            title: "Response Body",
            color: .indigo,
            action: ActionViewModel(
                action: { [unowned self] in isResponseRawLinkActive = true },
                title: "View"
            ),
            items: [
                ("Content-Type", request.response?.contentType?.rawValue),
                ("Size", request.isFromCache ? size + " (from cache)": size)
            ]
        )
    }

    // MARK: - Timings

    var timingDetailsViewModel: KeyValueSectionViewModel? {
        guard let taskInterval = request.metrics?.taskInterval else { return nil }
        return KeyValueSectionViewModel(title: "Timing", color: .orange, items: [
            ("Start Date", dateFormatter.string(from: taskInterval.start)),
            ("End Date", dateFormatter.string(from: taskInterval.end)),
            ("Duration", DurationFormatter.string(from: taskInterval.duration)),
            ("Redirect Count", (request.metrics?.redirectCount ?? 0).description)
        ])
    }

    // MARK: - Destinations

    var requestBodyViewModel: FileViewerViewModel {
        FileViewerViewModel(
            title: "Request",
            context: request.requestFileViewerContext,
            data: { [weak self] in self?.requestData ?? Data() }
        )
    }

    private var requestData: Data? {
        request.requestBody?.data
    }

    var responseBodyViewModel: FileViewerViewModel {
        FileViewerViewModel(
            title: "Response",
            context: request.responseFileViewerContext,
            data: { [weak self] in self?.responseData ?? Data() }
        )
    }

    private var responseData: Data? {
        request.responseBody?.data
    }

#if os(tvOS)
    var timingViewModel: TimingViewModel? {
        details?.metrics.map(TimingViewModel.init)
    }
#endif
}

// MARK: - Private

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    return formatter
}()
