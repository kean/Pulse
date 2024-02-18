// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation

extension LoggerStore {
    /// The store info.
    public struct Info: Codable, Sendable {
        // MARK: Store Info

        /// The id of the store.
        ///
        /// - note: If you create a copy of the store for exporting, the copy
        /// gets its own unique ID.
        public var storeId: UUID

        /// The internal version of the store.
        public var storeVersion: String

        // MARK: Creation Dates

        /// The date the store was originally created.
        public var creationDate: Date
        /// The date the store was last modified.
        public var modifiedDate: Date

        // MARK: Usage Statistics

        /// The numbers of recorded messages.
        ///
        /// - note: This excludes the technical messages associated with the
        /// network requests.
        public var messageCount: Int
        /// The number of recorded network requests.
        public var taskCount: Int
        /// The number of stored network response and requests bodies.
        public var blobCount: Int
        /// The complete size of the store, including the database and all
        /// externally stored blobs.
        public var totalStoreSize: Int64
        /// The size of stored network response and requests bodies.
        public var blobsSize: Int64
        /// The size of compressed stored network response and requests bodies.
        /// The blobs are compressed by default.
        public var blobsDecompressedSize: Int64

        // MARK: App and Device Info

        /// Information about the app which created the store.
        public var appInfo: AppInfo
        /// Information about the device which created the store.
        public var deviceInfo: DeviceInfo

        public struct AppInfo: Codable, Sendable {
            public let bundleIdentifier: String?
            public let name: String?
            public let version: String?
            public let build: String?
            /// Base64-encoded app icon (32x32 pixels). Added in 3.5.7
            public let icon: String?
        }

        public struct DeviceInfo: Codable, Sendable {
            public let name: String
            public let model: String
            public let localizedModel: String
            public let systemName: String
            public let systemVersion: String
        }

        /// Reads info from the given archive.
        ///
        /// - important: This API is designed to be used only with Pulse documents
        /// exported from the app without unarchiving the document. If you need
        /// to get info about the current store, use ``LoggerStore/Info``.
        public static func make(storeURL: URL) throws -> Info {
            let document = try PulseDocument(documentURL: storeURL)
            defer { try? document.close() }
            let info = try document.open()
            return info
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
        LoggerStore.Info.AppInfo(
            bundleIdentifier: AppInfo.bundleIdentifier,
            name: AppInfo.appName,
            version: AppInfo.appVersion,
            build: AppInfo.appBuild,
            icon: getAppIcon()?.base64EncodedString()
        )
    }
}

private func getAppIcon() -> Data? {
    guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String:Any],
          let primaryIcons = icons["CFBundlePrimaryIcon"] as? [String:Any],
          let files = primaryIcons["CFBundleIconFiles"] as? [String],
          let lastIcon = files.last,
          let image = PlatformImage(named: lastIcon),
          let data = Graphics.encode(image),
          let thumbnail = Graphics.makeThumbnail(from: data, targetSize: 32) else { return nil }
    return Graphics.encode(thumbnail)
}

#if os(iOS) || os(tvOS) || os(visionOS)
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
