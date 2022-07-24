// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore
import Combine
import CoreData

final class ConsoleNetworkRequestViewModel: Pinnable, ObservableObject {
#if os(iOS)
    lazy var time = ConsoleMessageViewModel.timeFormatter.string(from: request.createdAt)
    var badgeColor: UIColor = .gray
#else
    var badgeColor: Color = .gray
#endif
    var status: String = ""
    var title: String = ""
    var text: String = ""
    var state: LoggerNetworkRequestEntity.State = .pending

    private let request: LoggerNetworkRequestEntity
    private let store: LoggerStore
    private var cancellable: AnyCancellable?

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    init(request: LoggerNetworkRequestEntity, store: LoggerStore) {
        self.request = request
        self.store = store

        self.refresh()

        self.cancellable = request.objectWillChange.sink { [weak self] in
            withAnimation {
                self?.refresh()
                self?.objectWillChange.send()
            }
        }
    }

    private func refresh() {
        let time = ConsoleMessageViewModel.timeFormatter.string(from: request.createdAt)
        let state = request.state
        var prefix: String
        switch request.state {
        case .pending:
            prefix = "PENDING"
            if request.totalUnitCount > 0 {
                func format(_ bytes: Int64) -> String {
                    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
                }
                prefix += " · \(format(request.completedUnitCount)) / \(format(request.totalUnitCount))"
            }
        case .success:
            prefix = StatusCodeFormatter.string(for: Int(request.statusCode))
        case .failure:
            if request.errorCode != 0 {
                prefix = "\(request.errorCode) \(descriptionForURLErrorCode(Int(request.errorCode)))"
            } else {
                prefix = StatusCodeFormatter.string(for: Int(request.statusCode))
            }
        }

#if os(iOS)
        self.status = ""
        var title = prefix
        if request.duration > 0 {
            title += " · \(DurationFormatter.string(from: request.duration))"
        }
        func addSize(_ size: Int64) {
            let sizeText = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            title += " · \(request.isFromCache ? "Cache" : sizeText)"
        }
        if request.responseBodySize > 0 {
            let sizeText = ByteCountFormatter.string(fromByteCount: request.responseBodySize, countStyle: .file)
            title += " · \(request.isFromCache ? "Cache" : sizeText)"
        }

        self.title = title

        switch state {
        case .pending: self.badgeColor = .systemYellow
        case .success: self.badgeColor = .systemGreen
        case .failure: self.badgeColor = .systemRed
        }

#else
        if request.responseBodySize > 0 {
            let size = ByteCountFormatter.string(fromByteCount: request.responseBodySize, countStyle: .file)
            prefix += " · \(request.isFromCache ? "Cache" : size)"
        }
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

        self.state = request.state
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
