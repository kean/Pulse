// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS)

import CoreData
import Combine
import Pulse
import WatchConnectivity
import SwiftUI

final class LoggerSyncSession: NSObject, ObservableObject {
    static let shared = LoggerSyncSession()

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
        guard file.metadata?[pulseDocumentMarkerKey] != nil else {
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

#endif

#if os(iOS) || os(watchOS)
let pulseDocumentMarkerKey = "com.github.kean.pulse.imported-store-marker"
#endif
