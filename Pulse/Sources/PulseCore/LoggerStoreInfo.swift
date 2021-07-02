// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import Foundation

public struct LoggerStoreInfo: Codable {
    public let id: UUID
    public let device: DeviceInfo
    public let storeVersion: String
    public let messageCount: Int
    public let requestCount: Int
    public let databaseSize: Int64
    public let blobsSize: Int64
    public let createdDate: Date
    public let modifiedDate: Date
    public let archivedDate: Date

    public struct DeviceInfo: Codable {
        public let name: String
        public let model: String
        public let localizedModel: String
        public let systemName: String
        public let systemVersion: String
    }

    public static func make(storeURL: URL) -> LoggerStoreInfo? {
        guard let archive = Archive(url: storeURL, accessMode: .read),
              let entry = archive[manifestFileName],
              let data = archive.getData(for: entry) else {
            return nil
        }
        return try? JSONDecoder().decode(LoggerStoreInfo.self, from: data)
    }

    static func make(archive: IndexedArchive) throws -> LoggerStoreInfo {
        guard let data = archive.dataForEntry(manifestFileName) else {
            throw NSError(domain: NSErrorDomain() as String, code: NSURLErrorResourceUnavailable, userInfo: [NSLocalizedDescriptionKey: "Store manifest is missing"])
        }
        return try JSONDecoder().decode(LoggerStoreInfo.self, from: data)
    }
}

#if os(iOS) || os(tvOS)
import UIKit

extension LoggerStoreInfo.DeviceInfo {
    static func make() -> LoggerStoreInfo.DeviceInfo {
        let device = UIDevice.current
        return LoggerStoreInfo.DeviceInfo(
            name: device.name,
            model: device.model,
            localizedModel: device.localizedModel,
            systemName: device.systemName,
            systemVersion: device.systemVersion
        )
    }
}
#elseif os(watchOS)
import WatchKit

extension LoggerStoreInfo.DeviceInfo {
    static func make() -> LoggerStoreInfo.DeviceInfo {
        let device = WKInterfaceDevice.current()
        return LoggerStoreInfo.DeviceInfo(
            name: device.name,
            model: device.model,
            localizedModel: device.localizedModel,
            systemName: device.systemName,
            systemVersion: device.systemVersion
        )
    }
}
#else
import AppKit

extension LoggerStoreInfo.DeviceInfo {
    static func make() -> LoggerStoreInfo.DeviceInfo {
        return LoggerStoreInfo.DeviceInfo(
            name: Host.current().name ?? "unknown",
            model: "unknown",
            localizedModel: "unknown",
            systemName: "macOS",
            systemVersion: ProcessInfo().operatingSystemVersionString
        )
    }
}
#endif
