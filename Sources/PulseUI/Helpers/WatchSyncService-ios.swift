// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS)

import CoreData
import Combine
import Pulse
import WatchConnectivity
import SwiftUI

final class WatchSyncService: NSObject, ObservableObject {
    static let shared = WatchSyncService()

    @Published private(set) var importedStoreURL: URL?

    override init() {
        super.init()

        let storeURL = makeImportedStoreURL()
        if FileManager.default.fileExists(atPath: storeURL.absoluteString) {
            self.importedStoreURL = storeURL
        }
    }

    func removeImportedDocument() {
        try? importedStoreURL.map(FileManager.default.removeItem)
        importedStoreURL = nil
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard file.metadata?[WatchSyncService.pulseDocumentMarkerKey] != nil else {
            return
        }
        let storeURL = makeImportedStoreURL()
        try? FileManager.default.removeItem(at: storeURL)
        try? FileManager.default.moveItem(at: file.fileURL, to: storeURL)
        DispatchQueue.main.async {
            self.importedStoreURL = storeURL
        }
    }
}

private func makeImportedStoreURL() -> URL {
    LoggerStore.logsURL.appendingPathComponent("import.pulse")
}

extension LoggerStore {
    /// Processes the file received from the companion watchOS apps, ignoring
    /// any files sent not by the Pulse framework.
    public static func session(_ session: WCSession, didReceive file: WCSessionFile) {
        WatchSyncService.shared.session(session, didReceive: file)
    }
}

#endif

#if os(iOS) || os(watchOS)
extension WatchSyncService {
    static let pulseDocumentMarkerKey = "com.github.kean.pulse.imported-store-marker"
}
#endif
