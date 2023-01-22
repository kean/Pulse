// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine
import CoreData

final class ConsoleTaskCellViewModel: ObservableObject {
    private(set) var pins: PinButtonViewModel?
    private(set) var progress: ProgressViewModel?
    private var task: NetworkTaskEntity?

    private var cancellable: AnyCancellable?

    func bind(_ task: NetworkTaskEntity) {
        guard task !== self.task else {
            return
        }

        self.task = task

        cancellable = nil
        progress = nil

        if task.state == .pending {
            cancellable = task.publisher(for: \.requestState).sink { [weak self] _ in
                withAnimation {
                    self?.objectWillChange.send()
                }
            }
            self.progress = ProgressViewModel(task: task)
        }
        pins = PinButtonViewModel(task)
    }

#if os(iOS) || os(macOS)
    func share(as output: ShareOutput) -> ShareItems {
        task.map { ShareService.share($0, as: output) } ?? ShareItems([])
    }
#endif
}
