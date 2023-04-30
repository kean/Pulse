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
#if os(watchOS)
    @Published private(set) var fileTransferStatus: FileTransferStatus = .initial
    @Published var fileTransferError: FileTransferError?
#endif

    private var cancellables: [AnyCancellable] = []

    var isRemoteLoggingAvailable: Bool {
        store === RemoteLogger.shared.store
    }

    init(store: LoggerStore) {
        self.store = store

#if os(watchOS)
        LoggerSyncSession.shared.$fileTransferStatus.sink(receiveValue: { [weak self] in
            self?.fileTransferStatus = $0
            if case let .failure(error) = $0 {
                self?.fileTransferError = FileTransferError(message: error.localizedDescription)
            }
        }).store(in: &cancellables)
#endif
    }

    func buttonRemoveAllMessagesTapped() {
        store.removeAll()

#if os(iOS)
        runHapticFeedback(.success)
#endif
    }

#if os(watchOS)
    func tranferStore() {
        LoggerSyncSession.shared.transfer(store: store)
    }
#endif
}

#endif
