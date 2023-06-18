// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(watchOS)

import CoreData
import Combine
import Pulse
import WatchConnectivity
import SwiftUI

#warning("add support for cancelling")
#warning("check if enabled")
@MainActor
final class FileTransferViewModel: ObservableObject {
    @Published private(set) var state: FileTransferStatus = .ready
    @Published var error: FileTransferError?

    private var observer: AnyObject?

    var isButtonDisabled: Bool {
        switch state {
        case .ready: return false
        default: return true
        }
    }

    func share(store: LoggerStore) {
        guard case .ready = state else { return }

        state = .exporting
        let storeURL = makeExportedStoreURL()

        Task {
            try? FileManager.default.removeItem(at: storeURL)
            do {
                try await store.export(to: storeURL)
            }  catch {
                self.didComplete(with: error)
            }
            let session = WCSession.default.transferFile(storeURL, metadata: [
                pulseDocumentMarkerKey: true
            ])
            self.state = .sending(session.progress)

            observer = session.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
                DispatchQueue.main.async {
                    print("Progress: \(progress.fractionCompleted)")
//                    self?.didUpdateProgress(progress)
                }
            }
        }
    }

    @MainActor
    private func didUpdateProgress(_ progress: Progress) {
        DispatchQueue.main.async {
            self.objectWillChange.send()
            if progress.fractionCompleted == 1 {
                self.didComplete(with: nil)
            }
        }
    }

    private func didComplete(with error: Error?) {
        if let error {
            self.state = .failure(error)
            self.error = FileTransferError(error: error)
        } else {
            self.state = .success
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
            self.state = .ready
            self.error = nil
        }
    }
}

struct FileTransferError: Identifiable {
    let id = UUID()
    let error: Error
}

private func makeExportedStoreURL() -> URL {
    LoggerStore.logsURL.appendingPathComponent("exported.pulse")
}

#warning("do we need SessionDelegate")
//private final class SessionDelegate: NSObject, WCSessionDelegate {
//    unowned var session: LoggerSyncSession!
//
//    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
//
//    func session(_ session: WCSession, didReceive file: WCSessionFile) {}
//
//    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
//        DispatchQueue.main.async {
//            self.session.directory?.remove()
//            if let error = error {
//                self.session.fileTransferStatus = .failure(error)
//            } else {
//                self.session.fileTransferStatus = .success
//            }
//            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
//                self.session.fileTransferStatus = .initial
//            }
//        }
//    }
//}

enum FileTransferStatus {
    case ready
    case exporting
    case sending(Progress)
    case failure(Error)
    case success

    var title: String {
        switch self {
        case .ready: return "Send to iOS App"
        case .exporting: return "Exporting..."
        case .sending: return "Sending..."
        case .failure: return "Transfer Failed"
        case .success: return "Store Sent"
        }
    }
}

#endif
