// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(watchOS)

import CoreData
import Combine
import Pulse
import WatchConnectivity
import SwiftUI

final class LoggerSyncSession: ObservableObject {
    @Published fileprivate(set) var fileTransferStatus: FileTransferStatus = .initial

    private let delegate: SessionDelegate
    fileprivate var directory: TemporaryDirectory?

    static let shared = LoggerSyncSession()

    init() {
        self.delegate = SessionDelegate()
        self.delegate.session = self

        if WCSession.isSupported() {
            WCSession.default.delegate = delegate
            WCSession.default.activate()
        }
    }
    func transfer(store: LoggerStore) {
        let directory = TemporaryDirectory()
        let date = makeCurrentDate()
        let storeURL = directory.url.appendingPathComponent("logs-\(date).pulse", isDirectory: true)
        Task {
            _ = try? await store.export(to: storeURL)
            let session = WCSession.default.transferFile(storeURL, metadata: nil)
            DispatchQueue.main.async {
                self.fileTransferStatus = .sending(session.progress)
                self.directory = directory
            }
        }
    }
}

private final class SessionDelegate: NSObject, WCSessionDelegate {
    unowned var session: LoggerSyncSession!

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func session(_ session: WCSession, didReceive file: WCSessionFile) {}

    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        DispatchQueue.main.async {
            self.session.directory?.remove()
            if let error = error {
                self.session.fileTransferStatus = .failure(error)
            } else {
                self.session.fileTransferStatus = .success
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                self.session.fileTransferStatus = .initial
            }
        }
    }
}

enum FileTransferStatus {
    case initial
    case sending(Progress)
    case failure(Error)
    case success

    var title: String {
        switch self {
        case .initial:
            return "Send to iPhone"
        case .failure:
            return "Transfer Failed"
        case .sending:
            return "Sending..."
        case .success:
            return "Store Sent"
        }
    }

    var isButtonDisabled: Bool {
        switch self {
        case .initial:
            return false
        default:
            return true
        }
    }
}

struct FileTransferError: Identifiable {
    let id = UUID()
    let message: String
}

#endif
