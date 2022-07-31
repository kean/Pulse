// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore
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
    private var details: DecodedNetworkRequestDetailsEntity
    private let store: LoggerStore
    private var cancellable: AnyCancellable?

    init(request: LoggerNetworkRequestEntity, store: LoggerStore) {
        self.request = request
        self.details = DecodedNetworkRequestDetailsEntity(request: request)
        self.store = store

        cancellable = request.objectWillChange.sink { [weak self] in self?.refresh() }
    }

    private func refresh() {
        details = DecodedNetworkRequestDetailsEntity(request: request)
        withAnimation {
            objectWillChange.send()
        }
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
        details.lastTransactionDetails.map {
            NetworkInspectorTransferInfoViewModel(details: $0, taskType: request.taskType ?? .dataTask)
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
        guard let error = details.error else { return nil }
        return KeyValueSectionViewModel.makeErrorDetails(for: error) { [unowned self] in
            isErrorRawLinkActive = true
        }
    }

    // MARK: - Request (Original)

    var originalRequestSummary: KeyValueSectionViewModel? {
        details.originalRequest.map(KeyValueSectionViewModel.makeSummary)
    }

#if os(iOS) || os(macOS)
    var originalRequestQueryItems: KeyValueSectionViewModel? {
        details.originalRequest?.url.flatMap {
            KeyValueSectionViewModel.makeQueryItems(for: $0) { [unowned self] in
                self.isOriginalQueryItemsLinkActive = true
            }
        }
    }
#endif

    var originalRequestParameters: KeyValueSectionViewModel? {
        details.originalRequest.map(KeyValueSectionViewModel.makeParameters)
    }

    var originalRequestHeaders: KeyValueSectionViewModel {
        KeyValueSectionViewModel.makeRequestHeaders(for: details.originalRequest?.headers ?? [:]) { [unowned self] in
            self.isOriginalRequestHeadersLinkActive = true
        }
    }

    var requestBodySection: KeyValueSectionViewModel {
        guard request.requestBodyKey != nil, request.requestBodySize > 0 else {
            return KeyValueSectionViewModel(title: "Request Body", color: .blue)
        }
        let contentType = details.originalRequest?.headers.first(where: { $0.key == "Content-Type" })?.value ?? "–"
        return KeyValueSectionViewModel(
            title: "Request Body",
            color: .blue,
            action: ActionViewModel(
                action: { [unowned self] in isRequestRawLinkActive = true },
                title: "View"
            ),
            items: [
                ("Content-Type", contentType),
                ("Size", ByteCountFormatter.string(fromByteCount: request.requestBodySize, countStyle: .file))
            ]
        )
    }

    // MARK: - Request (Current)

    var currentRequestSummary: KeyValueSectionViewModel? {
        details.currentRequest.map(KeyValueSectionViewModel.makeSummary)
    }

#if os(iOS) || os(macOS)
    var currentRequestQueryItems: KeyValueSectionViewModel? {
        details.originalRequest?.url.flatMap {
            KeyValueSectionViewModel.makeQueryItems(for: $0) { [unowned self] in
                self.isCurrentQueryItemsLinkActive = true
            }
        }
    }
#endif

    var currentRequestParameters: KeyValueSectionViewModel? {
        details.currentRequest.map(KeyValueSectionViewModel.makeParameters)
    }

    var currentRequestHeaders: KeyValueSectionViewModel {
        KeyValueSectionViewModel.makeRequestHeaders(for: details.currentRequest?.headers ?? [:]) { [unowned self] in
            self.isCurrentRequestHeadersLinkActive = true
        }
    }

    var currentRequestBodySection: KeyValueSectionViewModel {
        guard request.requestBodyKey != nil, request.requestBodySize > 0 else {
            return KeyValueSectionViewModel(title: "Request Body", color: .blue)
        }
        let contentType = details.currentRequest?.headers.first(where: { $0.key == "Content-Type" })?.value ?? "–"
        return KeyValueSectionViewModel(
            title: "Request Body",
            color: .blue,
            action: ActionViewModel(
                action: { [unowned self] in isRequestRawLinkActive = true },
                title: "View"
            ),
            items: [
                ("Content-Type", contentType),
                ("Size", ByteCountFormatter.string(fromByteCount: request.requestBodySize, countStyle: .file))
            ]
        )
    }

    // MARK: - Response

    var responseSummary: KeyValueSectionViewModel? {
        details.response.map(KeyValueSectionViewModel.makeSummary)
    }

    var responseHeaders: KeyValueSectionViewModel {
        KeyValueSectionViewModel.makeResponseHeaders(for: details.response?.headers ?? [:]) { [unowned self] in
            self.isResponseHeadearsRawLinkActive = true
        }
    }

    var responseBodySection: KeyValueSectionViewModel {
        if request.taskType == .downloadTask, request.responseBodySize > 0 {
            return KeyValueSectionViewModel(title: "Response Body", color: .indigo, items: [
                ("Download Size", ByteCountFormatter.string(fromByteCount: request.responseBodySize, countStyle: .file))
            ])
        }
        guard request.responseBodyKey != nil, request.responseBodySize > 0 else {
            return KeyValueSectionViewModel(title: "Response Body", color: .indigo)
        }
        let contentType = details.response?.headers.first(where: { $0.key == "Content-Type" })?.value ?? "–"
        let size = ByteCountFormatter.string(fromByteCount: request.responseBodySize, countStyle: .file)
        return KeyValueSectionViewModel(
            title: "Response Body",
            color: .indigo,
            action: ActionViewModel(
                action: { [unowned self] in isResponseRawLinkActive = true },
                title: "View"
            ),
            items: [
                ("Content-Type", contentType),
                ("Size", request.isFromCache ? size + " (from cache)": size)
            ]
        )
    }

    // MARK: - Timings

    var timingDetailsViewModel: KeyValueSectionViewModel? {
        guard let taskInterval = request.taskInterval else { return nil }
        return KeyValueSectionViewModel(title: "Timing", color: .orange, items: [
            ("Start Date", dateFormatter.string(from: taskInterval.start)),
            ("End Date", dateFormatter.string(from: taskInterval.end)),
            ("Duration", DurationFormatter.string(from: taskInterval.duration)),
            ("Redirect Count", request.redirectCount.description)
        ])
    }

    // MARK: - Destinations

    var requestBodyViewModel: FileViewerViewModel {
        FileViewerViewModel(
            title: "Request",
            contentType: details.originalRequest?.headers["Content-Type"],
            originalSize: request.requestBodySize,
            data: { [weak self] in self?.requestData ?? Data() }
        )
    }

    private var requestData: Data? {
        request.requestBodyKey.flatMap(store.getData)
    }

    var responseBodyViewModel: FileViewerViewModel {
        FileViewerViewModel(
            title: "Response",
            contentType: request.contentType,
            originalSize: request.responseBodySize,
            data: { [weak self] in self?.responseData ?? Data() }
        )
    }

    private var responseData: Data? {
        request.responseBodyKey.flatMap(store.getData)
    }

#if os(tvOS)
    var timingViewModel: TimingViewModel? {
        details.metrics.map(TimingViewModel.init)
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
