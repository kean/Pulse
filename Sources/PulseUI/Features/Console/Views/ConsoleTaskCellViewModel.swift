// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine
import CoreData

final class ConsoleTaskCellViewModel: Pinnable, ObservableObject {
    private(set) lazy var time = ConsoleMessageCellViewModel.timeFormatter.string(from: task.createdAt)
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

        self.cancellable = task.objectWillChange.sink { [weak self] in
            withAnimation {
                self?.objectWillChange.send()
            }
        }
    }

    // MARK: Pins

    lazy var pinViewModel = PinButtonViewModel(task)

    // MARK: Context Menu

#if os(iOS) || os(macOS)
    func share(as output: ShareOutput) -> ShareItems {
        ShareService.share(task, as: output)
    }
#endif
}
