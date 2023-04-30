// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS)

import CoreData
import Combine
import Pulse
import WatchConnectivity
import SwiftUI

final class LoggerSyncSession: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = LoggerSyncSession()

    @Published private(set) var importedStoreURL: URL?

    override init() {
        super.init()

        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }

        let storeURL = getImportedStoreURL()
        if FileManager.default.fileExists(atPath: storeURL.absoluteString) {
            self.importedStoreURL = storeURL
        }
    }

    func removeImportedDocument() {
        try? importedStoreURL.map(FileManager.default.removeItem)
        importedStoreURL = nil
    }

    // MARK: WCSessionDelegate

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {}
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let storeURL = getImportedStoreURL()
        try? FileManager.default.removeItem(at: storeURL)
        try? FileManager.default.moveItem(at: file.fileURL, to: storeURL)
        DispatchQueue.main.async {
            self.importedStoreURL = storeURL
        }
    }
}

private func getImportedStoreURL() -> URL {
    LoggerStore.logsURL.appendingPathComponent("import.pulse")
}

#endif
