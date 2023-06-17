// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(watchOS) || os(tvOS)

import SwiftUI
import Pulse
import Combine

final class SettingsViewModel: ObservableObject {
    let store: LoggerStore

    // Apple Watch file transfers
    private var cancellables: [AnyCancellable] = []

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
#endif
    }
}

#endif
