// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine
import CoreData

#warning("TODO: rework fullTitle, etc")
final class ConsoleNetworkRequestViewModel: Pinnable, ObservableObject {
    private(set) lazy var time = ConsoleMessageViewModel.timeFormatter.string(from: task.createdAt)
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

    var titleForTextRepresentation: String {
        "\(time) · \(title)"
    }

    private(set) var state: NetworkTaskEntity.State = .pending

    private(set) lazy var progress = ProgressViewModel(task: task)

    private let task: NetworkTaskEntity
    private var cancellable: AnyCancellable?

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    init(task: NetworkTaskEntity) {
        self.task = task
        self.progress = ProgressViewModel(task: task)

        self.refresh()

        self.cancellable = task.objectWillChange.sink { [weak self] in
            self?.refresh()
            withAnimation {
                self?.objectWillChange.send()
            }
        }
    }

#warning("TODO: add subline with details instead of cramming everything into the header (?)")

    private func refresh() {
        let state = task.state

        self.title = ConsoleFormatter.details(for: task)
        self.text = task.url ?? "URL Unavailable"

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

        self.state = task.state
    }

    // MARK: Pins

    lazy var pinViewModel = PinButtonViewModel(task: task)

    // MARK: Context Menu

#if os(iOS) || os(macOS)

    func shareAsPlainText() -> ShareItems {
        ShareItems([ConsoleShareService.share(task, output: .plainText)])
    }

    func shareAsHTML() -> ShareItems {
        let text = ConsoleShareService.share(task, output: .html)
        let directory = TemporaryDirectory()
        let fileURL = directory.write(text: text, extension: "html")
        return ShareItems([fileURL], cleanup: directory.remove)
    }

    func shareAsCURL() -> ShareItems {
        ShareItems([task.cURLDescription()])
    }

    var containsResponseData: Bool {
        task.responseBodySize > 0
    }

    // WARNING: This call is relatively expensive.
    var responseString: String? {
        task.responseBody?.data.flatMap { String(data: $0, encoding: .utf8) }
    }

    var url: String? {
        task.url
    }

    var host: String? {
        task.host?.value
    }

    var cURLDescription: String {
        task.cURLDescription()
    }
#endif
}
