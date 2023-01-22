// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine
import CoreData

final class ConsoleTaskCellViewModel: ObservableObject {
    private(set) var pins: PinButtonViewModel?
    private var task: NetworkTaskEntity?

    private var cancellable: AnyCancellable?

    func bind(_ task: NetworkTaskEntity) {
        guard task !== self.task else {
            return
        }

        self.task = task

        cancellable?.cancel()
        cancellable = nil

        if task.state == .pending {
            cancellable = task.publisher(for: \.requestState).dropFirst().sink { [weak self] state in
                withAnimation {
                    self?.objectWillChange.send()
                }
            }
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
