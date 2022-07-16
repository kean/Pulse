// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore
import Combine
import CoreData

final class ConsoleNetworkRequestViewModel: Pinnable {
#if os(iOS)
    lazy var time = ConsoleMessageViewModel.timeFormatter.string(from: request.createdAt)
    let badgeColor: UIColor
#else
    let badgeColor: Color
#endif
    let status: String
    let title: String
    let text: String

    private let request: LoggerNetworkRequestEntity
    private let store: LoggerStore

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    init(request: LoggerNetworkRequestEntity, store: LoggerStore) {
        let state = LoggerNetworkRequestEntity.State(rawValue: request.requestState) ?? .success

        let time = ConsoleMessageViewModel.timeFormatter.string(from: request.createdAt)
        let prefix: String
        switch state {
        case .pending:
            prefix = "PENDING"
        case .success:
            prefix = StatusCodeFormatter.string(for: Int(request.statusCode))
        case .failure:
            prefix = "\(request.errorCode) (\(descriptionForURLErrorCode(Int(request.errorCode))))"
        }

#if os(iOS)
        self.status = ""
        var title = prefix
        if request.duration > 0 {
            title += " · \(DurationFormatter.string(from: request.duration))"
        }
        self.title = title

        switch state {
        case .pending: self.badgeColor = .systemYellow
        case .success: self.badgeColor = .systemGreen
        case .failure: self.badgeColor = .systemRed
        }

#else
        self.status = prefix
        var title = "\(time)"
        if request.duration > 0 {
            title += " · \(DurationFormatter.string(from: request.duration))"
        }
        self.title = title

        switch state {
        case .pending: self.badgeColor = .yellow
        case .success: self.badgeColor = .green
        case .failure: self.badgeColor = .red
        }
#endif

        let method = request.httpMethod ?? "GET"
        self.text = method + " " + (request.url ?? "–")

        self.request = request

        self.store = store
    }

    // MARK: Pins

    lazy var pinViewModel = PinButtonViewModel(store: store, request: request)

    // MARK: Context Menu

    func shareAsPlainText() -> ShareItems {
        ShareItems([ConsoleShareService(store: store).share(request, output: .plainText)])
    }

    func shareAsMarkdown() -> ShareItems {
        let text = ConsoleShareService(store: store).share(request, output: .markdown)
        let directory = TemporaryDirectory()
        let fileURL = directory.write(text: text, extension: "markdown")
        return ShareItems([fileURL], cleanup: directory.remove)
    }

    func shareAsHTML() -> ShareItems {
        let text = ConsoleShareService(store: store).share(request, output: .html)
        let directory = TemporaryDirectory()
        let fileURL = directory.write(text: text, extension: "html")
        return ShareItems([fileURL], cleanup: directory.remove)
    }

    func shareAsCURL() -> ShareItems {
        let summary = NetworkLoggerSummary(request: request, store: store)
        return ShareItems([summary.cURLDescription()])
    }

    var containsResponseData: Bool {
        request.responseBodyKey != nil
    }

    // WARNING: This call is relatively expensive.
    var responseString: String? {
        request.responseBodyKey
            .flatMap(store.getData)
            .flatMap { String(data: $0, encoding: .utf8) }
    }

    var url: String? {
        request.url
    }

    var host: String? {
        request.host
    }

    var cURLDescription: String {
        NetworkLoggerSummary(request: request, store: store).cURLDescription()
    }
}
