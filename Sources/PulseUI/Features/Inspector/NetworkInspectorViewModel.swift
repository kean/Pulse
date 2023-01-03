// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#warning("TODO: creat ViewModel that are needed only")
#warning("TODO: populate items from there")
#warning("TODO: refactor")
#warning("TODO: use LazyReset")

#if os(iOS)

final class NetworkInspectorViewModel: ObservableObject {
    private(set) var title: String = ""

    let task: NetworkTaskEntity

    var taskStatus: String {
        switch task.state {
        case .pending:
            return _progressViewModel.title.capitalized
        case .success:
            return StatusCodeFormatter.string(for: Int(task.statusCode))
        case .failure:
            if task.errorCode != 0 {
                if task.errorDomain == URLError.errorDomain {
                    return "\(descriptionForURLErrorCode(Int(task.errorCode))) (\(task.errorCode))"
                } else if task.errorDomain == NetworkLogger.DecodingError.domain {
                    return "Decoding Failed"
                } else {
                    return "Failed"
                }
            } else {
                return StatusCodeFormatter.string(for: Int(task.statusCode))
            }
        }
    }

    private(set) lazy var _progressViewModel = ProgressViewModel(task: task)

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

    let duration: DurationViewModel

    @LazyReset var originalRequestCookies: [HTTPCookie]
    @LazyReset var currentRequestCookies: [HTTPCookie]
    @LazyReset var responseCookies: [HTTPCookie]

    private var cancellable: AnyCancellable?

    init(task: NetworkTaskEntity) {
        self.task = task
        self.duration = DurationViewModel(task: task)

        _originalRequestCookies = LazyReset { task.originalRequest?.cookies ?? [] }
        _currentRequestCookies = LazyReset { task.currentRequest?.cookies ?? [] }
        _responseCookies = LazyReset { task.responseCookies }

        if let url = task.url.flatMap(URL.init(string:)) {
            self.title = url.lastPathComponent
        }

        cancellable = task.objectWillChange.sink { [weak self] in
            self?.refresh()
        }
    }

    private func refresh() {
        _originalRequestCookies.reset()
        _currentRequestCookies.reset()
        _responseCookies.reset()

        withAnimation { objectWillChange.send() }
    }

    var transferViewModel: NetworkInspectorTransferInfoViewModel? {
        guard task.hasMetrics else { return nil }
        return NetworkInspectorTransferInfoViewModel(task: task, taskType: task.type ?? .dataTask)
    }

    var progressViewModel: ProgressViewModel? {
        guard task.state == .pending else { return nil }
        return _progressViewModel
    }

    var pin: PinButtonViewModel? {
        task.message.map(PinButtonViewModel.init)
    }

    func prepareForSharing() -> String {
        ConsoleShareService.share(task, output: .plainText)
    }

    var originalRequestHeadersViewModel: KeyValueSectionViewModel {
        KeyValueSectionViewModel.makeRequestHeaders(for: task.originalRequest?.headers ?? [:]) {}
    }

    var currnetRequestHeadersViewModel: KeyValueSectionViewModel {
        KeyValueSectionViewModel.makeRequestHeaders(for: task.currentRequest?.headers ?? [:]) {}
    }

    var requestDetailsViewModel: NetworkInspectorRequestDetailsViewModel {
        NetworkInspectorRequestDetailsViewModel(task: task)
    }

    var originalRequestCookiesString: NSAttributedString {
        makeAttributedString(for: task.originalRequest?.cookies ?? [], color: .blue)
    }

    var currentRequestCookiesString: NSAttributedString {
        makeAttributedString(for: task.currentRequest?.cookies ?? [], color: .blue)
    }

    var responseHeadersViewModel: KeyValueSectionViewModel {
        KeyValueSectionViewModel.makeResponseHeaders(for: task.currentRequest?.headers ?? [:], action: {})
    }

    var responseCookiesString: NSAttributedString {
        makeAttributedString(for: task.responseCookies, color: .indigo)
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
