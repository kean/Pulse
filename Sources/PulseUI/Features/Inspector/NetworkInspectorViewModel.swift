// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(iOS) || os(watchOS) || os(tvOS)

final class NetworkInspectorViewModel: ObservableObject {
    let title: String

    let task: NetworkTaskEntity

    @LazyReset var originalRequestHeaders: [String: String]
    @LazyReset var originalRequestCookies: [HTTPCookie]
    @LazyReset var currentRequestHeaders: [String: String]
    @LazyReset var currentRequestCookies: [HTTPCookie]
    @LazyReset var responseHeaders: [String: String]
    @LazyReset var responseCookies: [HTTPCookie]

    let durationViewModel: DurationViewModel
    private(set) lazy var _progressViewModel = ProgressViewModel(task: task)

    private var cancellable: AnyCancellable?

    init(task: NetworkTaskEntity) {
        self.task = task
        self.durationViewModel = DurationViewModel(task: task)

        _originalRequestHeaders = LazyReset { task.originalRequest?.headers ?? [:] }
        _originalRequestCookies = LazyReset { task.originalRequest?.cookies ?? [] }
        _currentRequestHeaders = LazyReset { task.originalRequest?.headers ?? [:] }
        _currentRequestCookies = LazyReset { task.currentRequest?.cookies ?? [] }
        _responseHeaders = LazyReset { task.response?.headers ?? [:] }
        _responseCookies = LazyReset { task.responseCookies }

        if let url = task.url.flatMap(URL.init(string:)) {
            self.title = url.lastPathComponent
        } else {
            self.title = "Request"
        }

        cancellable = task.objectWillChange.sink { [weak self] in
            self?.refresh()
        }
    }

    private func refresh() {
        _originalRequestHeaders.reset()
        _originalRequestCookies.reset()
        _currentRequestHeaders.reset()
        _currentRequestCookies.reset()
        _responseHeaders.reset()
        _responseCookies.reset()

        withAnimation { objectWillChange.send() }
    }

    var status: String {
        switch task.state {
        case .pending:
            return _progressViewModel.title.capitalized
        case .success:
            return StatusCodeFormatter.string(for: Int(task.statusCode))
        case .failure:
            return ErrorFormatter.shortErrorDescription(for: task)
        }
    }

    var statusImageName: String {
        switch task.state {
        case .pending: return "clock.fill"
        case .success: return "checkmark.circle.fill"
        case .failure: return "exclamationmark.octagon.fill"
        }
    }

    var statusTintColor: Color {
        switch task.state {
        case .pending: return .orange
        case .success: return .green
        case .failure: return .red
        }
    }

    var transferViewModel: NetworkInspectorTransferInfoViewModel? {
        guard task.hasMetrics else { return nil }
        return NetworkInspectorTransferInfoViewModel(task: task, taskType: task.type ?? .dataTask)
    }

    var progressViewModel: ProgressViewModel? {
        guard task.state == .pending else { return nil }
        return _progressViewModel
    }

    var pinViewModel: PinButtonViewModel? {
        task.message.map(PinButtonViewModel.init)
    }

    func prepareForSharing() -> String {
#if !os(watchOS) && !os(tvOS)
        return ConsoleShareService.share(task, output: .plainText)
#else
        return "Sharing not supported on watchOS"
#endif
    }

    var originalRequestHeadersViewModel: KeyValueSectionViewModel {
        KeyValueSectionViewModel.makeRequestHeaders(for: originalRequestHeaders) {}
    }

    var currentRequestHeadersViewModel: KeyValueSectionViewModel {
        KeyValueSectionViewModel.makeRequestHeaders(for: currentRequestHeaders) {}
    }

    var originalRequestCookiesString: NSAttributedString {
        makeAttributedString(for: originalRequestCookies, color: .blue)
    }

    var currentRequestCookiesString: NSAttributedString {
        makeAttributedString(for: currentRequestCookies, color: .blue)
    }

    var responseHeadersViewModel: KeyValueSectionViewModel {
        KeyValueSectionViewModel.makeResponseHeaders(for: responseHeaders, action: {})
    }

    var responseCookiesString: NSAttributedString {
        makeAttributedString(for: responseCookies, color: .indigo)
    }
}

#else

final class NetworkInspectorViewModel: ObservableObject {
    private(set) var title: String = ""

    let summaryViewModel: NetworkInspectorSummaryViewModel
    let responseViewModel: NetworkInspectorResponseViewModel
    let requestViewModel: NetworkInspectorRequestViewModel
#if !os(watchOS) && !os(tvOS)
    let metricsViewModel: NetworkInspectorMetricsTabViewModel
#endif

#if os(macOS)
    let headersViewModel: NetworkInspectorHeadersTabViewModel
#endif

    // TODO: Make private
    let task: NetworkTaskEntity

    init(task: NetworkTaskEntity) {
        self.task = task

        if let url = task.url.flatMap(URL.init(string:)) {
            self.title = "/" + url.lastPathComponent
        }

        self.summaryViewModel = NetworkInspectorSummaryViewModel(task: task)
        self.responseViewModel = NetworkInspectorResponseViewModel(task: task)
        self.requestViewModel = NetworkInspectorRequestViewModel(task: task)
#if !os(watchOS) && !os(tvOS)
        self.metricsViewModel = NetworkInspectorMetricsTabViewModel(task: task)
#endif
#if os(macOS)
        self.headersViewModel = NetworkInspectorHeadersTabViewModel(task: task)
#endif
    }

#if os(iOS) || os(macOS)
    var pin: PinButtonViewModel? {
        task.message.map(PinButtonViewModel.init)
    }

    func prepareForSharing() -> String {
        ConsoleShareService.share(task, output: .plainText)
    }
#endif
}

#endif

private func makePreview(for cookies: [HTTPCookie]) -> [(String, String?)] {
    cookies
        .sorted(by: { $0.name.caseInsensitiveCompare($1.name) == .orderedAscending })
        .map { ($0.name, $0.value) }
}

private func makeAttributedString(for cookies: [HTTPCookie], color: Color) -> NSAttributedString {
    guard !cookies.isEmpty else {
        return NSAttributedString(string: "Empty")
    }
    var colorIndex = 0
    let colors: [Color] = [.blue, .purple, .orange, .red, .indigo, .green]

    let sections = cookies
        .sorted(by:  { $0.name.caseInsensitiveCompare($1.name) == .orderedAscending })
        .map {
            let section = KeyValueSectionViewModel.makeDetails(for: $0, color: colors[colorIndex])
            colorIndex += 1
            if colorIndex == colors.endIndex {
                colorIndex = 0
            }
            return section
        }
    let text = NSMutableAttributedString()
    for (index, section) in sections.enumerated() {
        text.append(section.asAttributedString())
        if index != sections.endIndex - 1 {
            text.append("\n\n")
        }
    }
    return text
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    return formatter
}()


final class DurationViewModel: ObservableObject {
    @Published var duration: String?

    private let task: NetworkTaskEntity
    private weak var timer: Timer?

    init(task: NetworkTaskEntity) {
        self.task = task
        switch task.state {
        case .pending:
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                self?.refreshPendingDuration()
            }
        case .failure, .success:
            duration = DurationFormatter.string(from: task.duration, isPrecise: false)
        }
    }

    private func refreshPendingDuration() {
        let duration = Date().timeIntervalSince(task.createdAt)
        if duration > 0 {
            self.duration = DurationFormatter.string(from: duration, isPrecise: false)
        }
        if task.state != .pending {
            timer?.invalidate()
        }
    }
}
