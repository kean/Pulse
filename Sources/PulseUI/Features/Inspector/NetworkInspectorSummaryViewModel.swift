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

    private(set) lazy var _progressViewModel = ProgressViewModel(task: task)

    private let task: NetworkTaskEntity
    private var cancellable: AnyCancellable?

    init(task: NetworkTaskEntity) {
        self.task = task
        cancellable = task.objectWillChange.sink { [weak self] in self?.refresh() }
    }

    private func refresh() {
        withAnimation { objectWillChange.send() }
    }

    var tintColor: Color {
        switch task.state {
        case .pending: return .orange
        case .success: return .green
        case .failure: return .red
        }
    }

    var statusImageName: String {
        switch task.state {
        case .pending: return "clock.fill"
        case .success: return "checkmark.circle.fill"
        case .failure: return "exclamationmark.octagon.fill"
        }
    }

    // MARK: - Header

    var transferViewModel: NetworkInspectorTransferInfoViewModel? {
        guard task.hasMetrics else { return nil }
        return NetworkInspectorTransferInfoViewModel(task: task, taskType: task.type ?? .dataTask)
    }

    var progressViewModel: ProgressViewModel? {
        guard task.state == .pending else { return nil }
        return _progressViewModel
    }

    // MARK: - Summary

    var summaryViewModel: KeyValueSectionViewModel {
        var items: [(String, String?)] = [
            ("URL", task.url ?? "–"),
            ("Method", task.httpMethod ?? "–")
        ]

        if task.state == .failure || task.state == .success {
            items.append(("Status Code", StatusCodeFormatter.string(for: task.statusCode)))
            if task.duration > 0 {
                items.append(("Duration", DurationFormatter.string(from: task.duration)))
            }
            items.append(("Source", task.isFromCache ? "Cache" : "Network"))
        }

        var title = task.type?.urlSessionTaskClassName ?? "Summary"
        #if os(watchOS)
        title = title.replacingOccurrences(of: "URLSession", with: "")
        #endif
        return KeyValueSectionViewModel(title: title, color: tintColor, items: items)
    }

    var errorModel: KeyValueSectionViewModel? {
        KeyValueSectionViewModel.makeErrorDetails(for: task) { [unowned self] in
            isErrorRawLinkActive = true
        }
    }

    // MARK: - Request (Original)

    var originalRequestSummary: KeyValueSectionViewModel? {
        task.originalRequest.map(KeyValueSectionViewModel.makeSummary)
    }

#if os(iOS) || os(macOS)
    var originalRequestQueryItems: KeyValueSectionViewModel? {
        task.originalRequest?.url.flatMap(URL.init).flatMap {
            KeyValueSectionViewModel.makeQueryItems(for: $0) { [unowned self] in
                self.isOriginalQueryItemsLinkActive = true
            }
        }
    }
#endif

    var originalRequestParameters: KeyValueSectionViewModel? {
        task.originalRequest.map(KeyValueSectionViewModel.makeParameters)
    }

    var originalRequestHeaders: KeyValueSectionViewModel {
        KeyValueSectionViewModel.makeRequestHeaders(for: task.originalRequest?.headers ?? [:]) { [unowned self] in
            self.isOriginalRequestHeadersLinkActive = true
        }
    }

    var requestBodySection: KeyValueSectionViewModel {
        guard task.requestBodySize > 0 else {
            return KeyValueSectionViewModel(title: "Request Body", color: .blue)
        }
        let contentType = (task.originalRequest?.headers ?? [:]).first(where: { $0.key == "Content-Type" })?.value ?? "–"
        return KeyValueSectionViewModel(
            title: "Request Body",
            color: .blue,
            action: ActionViewModel(
                action: { [unowned self] in isRequestRawLinkActive = true },
                title: "View"
            ),
            items: [
                ("Content-Type", contentType),
                ("Size", ByteCountFormatter.string(fromByteCount: task.requestBodySize))
            ]
        )
    }

    // MARK: - Request (Current)

    var currentRequestSummary: KeyValueSectionViewModel? {
        task.currentRequest.map(KeyValueSectionViewModel.makeSummary)
    }

#if os(iOS) || os(macOS)
    var currentRequestQueryItems: KeyValueSectionViewModel? {
        task.originalRequest?.url.flatMap(URL.init).flatMap {
            KeyValueSectionViewModel.makeQueryItems(for: $0) { [unowned self] in
                self.isCurrentQueryItemsLinkActive = true
            }
        }
    }
#endif

    var currentRequestParameters: KeyValueSectionViewModel? {
        task.currentRequest.map(KeyValueSectionViewModel.makeParameters)
    }

    var currentRequestHeaders: KeyValueSectionViewModel {
        KeyValueSectionViewModel.makeRequestHeaders(for: task.currentRequest?.headers ?? [:]) { [unowned self] in
            self.isCurrentRequestHeadersLinkActive = true
        }
    }

    var currentRequestBodySection: KeyValueSectionViewModel {
        guard task.requestBodySize > 0 else {
            return KeyValueSectionViewModel(title: "Request Body", color: .blue)
        }
        let contentType = task.currentRequest?.headers.first(where: { $0.key == "Content-Type" })?.value ?? "–"
        return KeyValueSectionViewModel(
            title: "Request Body",
            color: .blue,
            action: ActionViewModel(
                action: { [unowned self] in isRequestRawLinkActive = true },
                title: "View"
            ),
            items: [
                ("Content-Type", contentType),
                ("Size", ByteCountFormatter.string(fromByteCount: task.requestBodySize))
            ]
        )
    }

    // MARK: - Response

    var responseSummary: KeyValueSectionViewModel? {
        task.response.map(KeyValueSectionViewModel.makeSummary)
    }

    var responseHeaders: KeyValueSectionViewModel {
        KeyValueSectionViewModel.makeResponseHeaders(for: task.response?.headers ?? [:]) { [unowned self] in
            self.isResponseHeadearsRawLinkActive = true
        }
    }

    var responseBodySection: KeyValueSectionViewModel {
        if task.type == .downloadTask, task.responseBodySize > 0 {
            return KeyValueSectionViewModel(title: "Response Body", color: .indigo, items: [
                ("Download Size", ByteCountFormatter.string(fromByteCount: task.responseBodySize))
            ])
        }
        guard task.responseBodySize > 0 else {
            return KeyValueSectionViewModel(title: "Response Body", color: .indigo)
        }
        let size = ByteCountFormatter.string(fromByteCount: task.responseBodySize)
        return KeyValueSectionViewModel(
            title: "Response Body",
            color: .indigo,
            action: ActionViewModel(
                action: { [unowned self] in isResponseRawLinkActive = true },
                title: "View"
            ),
            items: [
                ("Content-Type", task.response?.contentType?.rawValue),
                ("Size", task.isFromCache ? size + " (from cache)": size)
            ]
        )
    }

    // MARK: - Timings

    var timingDetailsViewModel: KeyValueSectionViewModel? {
        guard let taskInterval = task.taskInterval else { return nil }
        return KeyValueSectionViewModel(title: "Timing", color: .orange, items: [
            ("Start Date", dateFormatter.string(from: taskInterval.start)),
            ("End Date", dateFormatter.string(from: taskInterval.end)),
            ("Duration", DurationFormatter.string(from: taskInterval.duration)),
            ("Redirect Count", task.redirectCount.description)
        ])
    }

    // MARK: - Destinations

    var requestBodyViewModel: FileViewerViewModel {
        FileViewerViewModel(
            title: "Request",
            context: task.requestFileViewerContext,
            data: { [weak self] in self?.requestData ?? Data() }
        )
    }

    private var requestData: Data? {
        task.requestBody?.data
    }

    var responseBodyViewModel: FileViewerViewModel {
        FileViewerViewModel(
            title: "Response",
            context: task.responseFileViewerContext,
            data: { [weak self] in self?.responseData ?? Data() }
        )
    }

    private var responseData: Data? {
        task.responseBody?.data
    }

#if os(tvOS)
    var timingViewModel: TimingViewModel? {
        guard task.hasMetrics else { return nil }
        return TimingViewModel(task: task)
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
