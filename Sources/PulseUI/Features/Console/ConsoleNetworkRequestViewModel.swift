// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore
import Combine
import CoreData

final class ConsoleNetworkRequestViewModel: Pinnable, ObservableObject {
    private(set) lazy var time = ConsoleMessageViewModel.timeFormatter.string(from: request.createdAt)
#if os(iOS)
    var uiBadgeColor: UIColor = .gray
#endif

    private(set) var badgeColor: Color = .gray
    private(set) var title: String = ""
    private(set) var text: String = ""

    var fullTitle: String {
        var title = self.title
#if !os(watchOS)
        if state == .pending, let details = progress.details {
            title += " · \(details)"
        }
#endif
#if os(macOS) || os(tvOS)
        title += " · \(time)"
#endif
        return title
    }

    private(set) var state: LoggerNetworkRequestEntity.State = .pending

    private(set) lazy var progress = ProgressViewModel(request: request)

    private let request: LoggerNetworkRequestEntity
    private let store: LoggerStore
    private var cancellable: AnyCancellable?

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    init(request: LoggerNetworkRequestEntity, store: LoggerStore) {
        self.request = request
        self.store = store

        self.progress = ProgressViewModel(request: request)

        self.refresh()

        self.cancellable = request.objectWillChange.sink { [weak self] in
            self?.refresh()
            withAnimation {
                self?.objectWillChange.send()
            }
        }
    }

    private func refresh() {
        let state = request.state

        var title: String
        switch request.state {
        case .pending:
            title = progress.title.uppercased()
        case .success:
            title = StatusCodeFormatter.string(for: Int(request.statusCode))
#if !os(watchOS)
            switch request.taskType ?? .dataTask {
            case .uploadTask:
                if request.requestBodySize > 0 {
                    let sizeText = ByteCountFormatter.string(fromByteCount: request.requestBodySize, countStyle: .file)
                    title += " · \(request.isFromCache ? "Cache" : sizeText)"
                }
            case .dataTask, .downloadTask:
                if request.responseBodySize > 0 {
                    let sizeText = ByteCountFormatter.string(fromByteCount: request.responseBodySize, countStyle: .file)
                    title += " · \(request.isFromCache ? "Cache" : sizeText)"
                }
            case .streamTask, .webSocketTask:
                break
            }
#endif
        case .failure:
            if request.errorCode != 0 {
                if request.errorDomain == URLError.errorDomain {
                    title = "\(request.errorCode) \(descriptionForURLErrorCode(Int(request.errorCode)))"
                } else if request.errorDomain == NetworkLoggerDecodingError.domain {
                    title = "Decoding Failed"
                } else {
                    title = "Error"
                }
            } else {
                title = StatusCodeFormatter.string(for: Int(request.statusCode))
            }
        }

        if request.duration > 0 {
            title += " · \(DurationFormatter.string(from: request.duration))"
        }

        self.title = title

        let method = request.httpMethod ?? "GET"
        self.text = method + " " + (request.url ?? "–")

#if os(iOS)
        switch state {
        case .pending: self.uiBadgeColor = .systemYellow
        case .success: self.uiBadgeColor = .systemGreen
        case .failure: self.uiBadgeColor = .systemRed
        }
#endif
        switch state {
        case .pending: self.badgeColor = .yellow
        case .success: self.badgeColor = .green
        case .failure: self.badgeColor = .red
        }

        self.state = request.state
    }

    // MARK: Pins

    lazy var pinViewModel = PinButtonViewModel(store: store, request: request)

    // MARK: Context Menu

#if os(iOS) || os(macOS)

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
        ShareItems([request.cURLDescription(store: store)])
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
        request.cURLDescription(store: store)
    }
#endif
}
