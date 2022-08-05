// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

final class SettingsViewModel: ObservableObject {
    let store: LoggerStore
    var onDismiss: (() -> Void)?

    var isArchive: Bool { store.isArchive }

    @available(iOS 14.0, *)
    var isRemoteLoggingAvailable: Bool {
        store === RemoteLogger.shared.store
    }

    init(store: LoggerStore) {
        self.store = store
    }

    func buttonRemoveAllMessagesTapped() {
        store.removeAll()

#if os(iOS)
        runHapticFeedback(.success)
        ToastView {
            HStack {
                Image(systemName: "trash")
                Text("All messages removed")
            }
        }.show()
#endif
    }
}
