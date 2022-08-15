// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import CoreData
import Combine

extension LoggerStore {

    /// The store creation options.
    public struct Options: OptionSet, Sendable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// Creates store if the file is missing. The intermediate directories must
        /// already exist.
        public static let create = Options(rawValue: 1 << 0)

        /// Reduces store size when it reaches the size limit by by removing the least
        /// recently added messages and blobs.
        public static let sweep = Options(rawValue: 1 << 1)

        /// Flushes entities to disk immediately and synchronously.
        ///
        /// - warning: This options is not recommended for general use. When it
        /// is enabled, all writes to the store happen immediately and synchronously
        /// as oppose to coalesced updates that significantly improve write efficiency.
        ///
        /// - note: This option will not improve remote logging speed because
        /// when the log events are registered in ``LoggerStore``, they are
        /// immediately retransmitted to the remote logger before any entities
        /// are even created.
        public static let synchronous = Options(rawValue: 1 << 2)
    }

    /// The store configuration.
    public struct Configuration: @unchecked Sendable {
        /// Size limit in bytes. `128 MB` by default.
        public var sizeLimit: Int64

        var blobSizeLimit: Int64 {
            Int64(Double(sizeLimit) * expectedBlobRatio)
        }

        var expectedBlobRatio = 0.7
        var trimRatio = 0.7

        /// Every 20 minutes.
        var sweepInterval: TimeInterval = 1200

        /// If enabled, all blobs will be stored in a compressed format and
        /// decompressed on the fly, significantly reducing the space usage.
        var isBlobCompressionEnabled = true

        /// Determines how often the messages are saved to the database. By default,
        /// 250 milliseconds - quickly enough, but avoiding too many individual writes.
        public var saveInterval: DispatchTimeInterval = .milliseconds(250)

        /// If `true`, the images added to the store as saved as small thumbnails.
        public var isStoringOnlyImageThumbnails = true

        /// Limit the maximum response size stored by the logger. The default
        /// value is `5 Mb`. The same limit applies to requests.
        public var responseBodySizeLimit: Int = 5 * 1048576

        var inlineLimit = 16384 // 16 KB

        /// By default, two weeks. The messages and requests that are older that
        /// two weeks will get automatically deleted.
        ///
        /// - note: This option request the store to be instantiated with a
        /// ``LoggerStore/Options/sweep`` option. The default store supports sweeps.
        public var maxAge: TimeInterval = 14 * 86400

        /// For tesing purposes.
        var makeCurrentDate: () -> Date = { Date() }

        /// Gets called when the store receives an event. You can use it to
        /// modify the event before it is stored in order, for example, filter
        /// out some sensitive information. If you return `nil`, the event
        /// is ignored completely.
        public var willHandleEvent: @Sendable (Event) -> Event? = { $0 }

        /// Initializes the configuration.
        ///
        /// - parameters:
        ///   - sizeLimit: The approximate limit of the logger store, including
        ///   both the database and the blobs. `128 Mb` by default.
        public init(sizeLimit: Int64 = 128 * 1_000_000) {
            self.sizeLimit = sizeLimit
        }
    }
}
