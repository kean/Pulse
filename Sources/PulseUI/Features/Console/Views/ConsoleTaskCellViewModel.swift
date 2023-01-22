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

    private var stateCancellable: AnyCancellable?
    private var progressCancellable: AnyCancellable?

    func bind(_ task: NetworkTaskEntity) {
        guard task !== self.task else {
            return
        }

        self.task = task

        stateCancellable = nil
        progress = nil

        if task.state == .pending {
            stateCancellable = task.publisher(for: \.requestState).sink { [weak self] _ in
                withAnimation {
                    self?.objectWillChange.send()
                }
            }
            let progress = ProgressViewModel(task: task)
            progressCancellable = progress.objectWillChange.sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            self.progress = progress
        }
        pins = PinButtonViewModel(task)

        objectWillChange.send()
    }

#if os(iOS) || os(macOS)
    func share(as output: ShareOutput) -> ShareItems {
        task.map { ShareService.share($0, as: output) } ?? ShareItems([])
    }
#endif
}
