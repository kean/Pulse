// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(watchOS)

import CoreData
import Combine
import Pulse
import WatchConnectivity
import SwiftUI

final class WatchConnectivityService: ObservableObject {
    static let shared = WatchConnectivityService()

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
        try? FileManager.default.removeItem(at: storeURL)

        store.export(to: storeURL) {
            self.didFinishExporting(to: storeURL, error: $0)
        }
    }

    private func didFinishExporting(to storeURL: URL, error: Error?) {
        guard error == nil else {
            return didComplete(with: error)
        }
        let session = WCSession.default.transferFile(storeURL, metadata: [
            WatchConnectivityService.pulseDocumentMarkerKey: true
        ])
        self.state = .sending(session)
    }

    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        DispatchQueue.main.async {
            guard case .sending(let currentFileTransfer) = self.state,
                  currentFileTransfer === fileTransfer else {
                return
            }
            self.didComplete(with: error)
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

private extension LoggerStore {
    func export(to targetURL: URL, _ completion: @escaping (Swift.Error?) -> Void) {
        Task.detached {
            do {
                try await self.export(to: targetURL)
                DispatchQueue.main.async {
                    completion(nil)
                }
            }  catch {
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        }
    }
}

enum FileTransferStatus {
    case ready
    case exporting
    case sending(WCSessionFileTransfer)
    case failure(Error)
    case success

    var title: String {
        switch self {
        case .ready: return "Send to Paired App"
        case .exporting: return "Exporting..."
        case .sending: return "Sending..."
        case .failure: return "Transfer Failed"
        case .success: return "Store Sent"
        }
    }
}

extension LoggerStore {
    /// Updates the status of the file transfer.
    public static func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Swift.Error?) {
        WatchConnectivityService.shared.session(session, didFinish: fileTransfer, error: error)
    }
}

#endif
