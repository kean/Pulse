// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine
import CoreData

final class ConsoleNetworkRequestViewModel: Pinnable, ObservableObject {
    private(set) lazy var time = ConsoleMessageViewModel.timeFormatter.string(from: task.createdAt)
#if os(iOS)
    private(set) var badgeColor: UIColor = .gray
#else
    private(set) var badgeColor: Color = .gray
#endif
    private(set) var state: NetworkTaskEntity.State = .pending
    private(set) lazy var progress = ProgressViewModel(task: task)

    let task: NetworkTaskEntity
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

    private func refresh() {
        let state = task.state

#if os(iOS)
        switch state {
        case .pending: self.badgeColor = .systemYellow
        case .success: self.badgeColor = .systemGreen
        case .failure: self.badgeColor = .systemRed
        }
#else
        switch state {
        case .pending: self.badgeColor = .yellow
        case .success: self.badgeColor = .green
        case .failure: self.badgeColor = .red
        }
#endif

        self.state = task.state
    }

    // MARK: Pins

    lazy var pinViewModel = PinButtonViewModel(task: task)

    // MARK: Context Menu

#if os(iOS) || os(macOS)

    func share(as output: ShareOutput) -> ShareItems {
        ShareService.share(task, as: output)
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
