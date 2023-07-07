// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS)

import CoreData
import Combine
import Pulse
import WatchConnectivity
import SwiftUI

final class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()

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

    func session(_ session: WCSession, didReceive file: WCSessionFile) -> Bool {
        guard file.metadata?[WatchConnectivityService.pulseDocumentMarkerKey] != nil else {
            return false
        }
        let storeURL = makeImportedStoreURL()
        try? FileManager.default.removeItem(at: storeURL)
        try? FileManager.default.moveItem(at: file.fileURL, to: storeURL)
        DispatchQueue.main.async {
            self.importedStoreURL = storeURL
        }
        return true
    }
}

private func makeImportedStoreURL() -> URL {
    LoggerStore.logsURL.appendingPathComponent("import.pulse")
}

extension LoggerStore {
    /// Processes the file received from the companion watchOS apps, ignoring
    /// any files sent not by the Pulse framework.
    /// Returns true if the provided file was a Pulse document
    @discardableResult
    public static func session(_ session: WCSession, didReceive file: WCSessionFile) -> Bool {
        return WatchConnectivityService.shared.session(session, didReceive: file)
    }
}

#endif

#if os(iOS) || os(watchOS)
extension WatchConnectivityService {
    static let pulseDocumentMarkerKey = "com.github.kean.pulse.imported-store-marker"
}
#endif
