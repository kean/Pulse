// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation

extension LoggerStore {
    /// The archive info.
    public struct Info: Codable, Sendable {
        public let id: UUID
        public let appInfo: AppInfo? // Should be always avail starting with 1.0
        public let device: DeviceInfo
        public let storeVersion: String
        public let messageCount: Int
        public let requestCount: Int
        public let databaseSize: Int64
        public let blobsSize: Int64
        public let createdDate: Date
        public let modifiedDate: Date
        public let archivedDate: Date

        public struct AppInfo: Codable, Sendable {
            public let bundleIdentifier: String?
            public let name: String?
            public let version: String?
            public let build: String?
        }

        public struct DeviceInfo: Codable, Sendable {
            public let name: String
            public let model: String
            public let localizedModel: String
            public let systemName: String
            public let systemVersion: String
        }

        public static func make(storeURL: URL) -> LoggerStore.Info? {
            guard let archive = Archive(url: storeURL, accessMode: .read),
                  let entry = archive[manifestFileName],
                  let data = archive.getData(for: entry) else {
                return nil
            }
            return try? JSONDecoder().decode(LoggerStore.Info.self, from: data)
        }

        static func make(archive: IndexedArchive) throws -> LoggerStore.Info {
            guard let data = archive.dataForEntry(manifestFileName) else {
                throw NSError(domain: NSErrorDomain() as String, code: NSURLErrorResourceUnavailable, userInfo: [NSLocalizedDescriptionKey: "Store manifest is missing"])
            }
            return try JSONDecoder().decode(LoggerStore.Info.self, from: data)
        }
    }
}

enum AppInfo {
    static var bundleIdentifier: String? { Bundle.main.bundleIdentifier }
    static var appName: String? { Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String }
    static var appVersion: String? { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String }
    static var appBuild: String? { Bundle.main.infoDictionary?["CFBundleVersion"] as? String }
}

extension LoggerStore.Info.AppInfo {
    static func make() -> LoggerStore.Info.AppInfo {
        return LoggerStore.Info.AppInfo(
            bundleIdentifier: AppInfo.bundleIdentifier,
            name: AppInfo.appName,
            version: AppInfo.appVersion,
            build: AppInfo.appBuild
        )
    }
}

#if os(iOS) || os(tvOS)
import UIKit

func getDeviceId() -> UUID? {
    UIDevice.current.identifierForVendor
}

extension LoggerStore.Info.DeviceInfo {
    static func make() -> LoggerStore.Info.DeviceInfo {
        let device = UIDevice.current
        return LoggerStore.Info.DeviceInfo(
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

func getDeviceId() -> UUID? {
    WKInterfaceDevice.current().identifierForVendor
}

extension LoggerStore.Info.DeviceInfo {
    static func make() -> LoggerStore.Info.DeviceInfo {
        let device = WKInterfaceDevice.current()
        return LoggerStore.Info.DeviceInfo(
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

extension LoggerStore.Info.DeviceInfo {
    static func make() -> LoggerStore.Info.DeviceInfo {
        return LoggerStore.Info.DeviceInfo(
            name: Host.current().name ?? "unknown",
            model: "unknown",
            localizedModel: "unknown",
            systemName: "macOS",
            systemVersion: ProcessInfo().operatingSystemVersionString
        )
    }
}

func getDeviceId() -> UUID? {
    return nil
}

#endif
