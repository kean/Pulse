// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import CoreData

public final class LoggerMessageEntity: NSManagedObject {
    @NSManaged public var createdAt: Date
    @NSManaged public var isPinned: Bool
    @NSManaged public var session: UUID
    @NSManaged public var level: Int16
    @NSManaged public var label: String
    @NSManaged public var text: String
    @NSManaged public var file: String
    @NSManaged public var function: String
    @NSManaged public var line: Int32 // Doubles as request state storage to save space
    @NSManaged public var metadata: Set<LoggerMetadataEntity>
    @NSManaged public var request: LoggerNetworkRequestEntity?
}

public final class LoggerMetadataEntity: NSManagedObject {
    @NSManaged public var key: String
    @NSManaged public var value: String
}

public final class LoggerNetworkRequestEntity: NSManagedObject {
    // Primary
    @NSManaged public var createdAt: Date
    @NSManaged public var isPinned: Bool
    @NSManaged public var session: UUID
    @NSManaged public var taskId: UUID
    @NSManaged public var message: LoggerMessageEntity?

    /// Returns task type
    public var taskType: NetworkLogger.TaskType? {
        NetworkLogger.TaskType(rawValue: rawTaskType)
    }
    @NSManaged public var rawTaskType: Int16

    // MARK: Request

    @NSManaged public var url: String?
    @NSManaged public var host: String?
    @NSManaged public var httpMethod: String?

    // MARK: Response

    @NSManaged public var statusCode: Int32
    @NSManaged public var errorDomain: String?
    @NSManaged public var errorCode: Int32
    /// Response content-type.
    @NSManaged public var responseContentType: String?
    /// Returns `true` if the response was returned from the local cache.
    @NSManaged public var isFromCache: Bool

    // MARK: State

    /// Returns request state.
    public var state: LoggerNetworkRequestEntity.State {
        LoggerNetworkRequestEntity.State(rawValue: requestState) ?? .pending
    }

    /// Contains ``State-swift.enum`` raw value.
    @NSManaged public var requestState: Int16
    /// Request progress.
    ///
    /// - note: The entity is created lazily when the first progress report
    /// is delivered. If no progress updates are delivered, it's never created.
    @NSManaged public var progress: LoggerNetworkRequestProgressEntity?

    // MARK: Metrics (Denormalized)

    // Timing
    /// Request start date.
    @NSManaged public var startDate: Date?
    /// Request end date.
    public var endDate: Date? {
        startDate.map { $0.addingTimeInterval(duration) }
    }
    /// Total request duration end date.
    @NSManaged public var duration: Double

    #warning("remove")
    /// Number of redirects.
    @NSManaged public var redirectCount: Int16

    // MARK: Details

    @NSManaged public var originalRequest: NetworkRequestEntity
    @NSManaged public var currentRequest: NetworkRequestEntity?
    @NSManaged public var response: NetworkResponseEntity?
    @NSManaged public var metrics: NetworkMetricsEntity?

    /// Returns request details.
    ///
    /// - important: Accessing it for the first time can be a relatively slow
    /// operation because it performs decoding on the fly, but the decoded
    /// entity is cached until the object is turned into a fault.
    public var details: LoggerNetworkRequestEntity.RequestDetails? {
        if let (details, count) = cachedDetails, count == detailsData?.data.count {
            return details
        }
        guard let compressedData = detailsData?.data,
              let data = try? compressedData.decompressed(),
              let details = try? JSONDecoder().decode(LoggerNetworkRequestEntity.RequestDetails.self, from: data as Data) else {
            return nil
        }
        self.cachedDetails = (details, compressedData.count)
        return details
    }

    public override func willTurnIntoFault() {
        super.willTurnIntoFault()
        cachedDetails = nil
    }

    private var cachedDetails: (RequestDetails, Int)?

    /// Request details (encoded and compressed ``LoggerNetworkRequestDetails``).
    @NSManaged var detailsData: LoggerInlineDataEntity?

    /// The request body handle.
    @NSManaged public var requestBody: LoggerBlobHandleEntity?
    /// The response body handle.
    @NSManaged public var responseBody: LoggerBlobHandleEntity?
    /// The size of the request body.
    @NSManaged public var requestBodySize: Int64
    /// The size of the response body.
    @NSManaged public var responseBodySize: Int64

    // MARK: Helpers

    /// Returns task interval (if available from metrics).
    public var taskInterval: DateInterval? {
        guard let startDate = self.startDate, let endDate = self.endDate else {
            return nil
        }
        return DateInterval(start: startDate, end: endDate)
    }

    public enum State: Int16 {
        case pending = 1
        case success = 2
        case failure = 3
    }

    /// The request details stored in a database in a denormalized format.
    public final class RequestDetails: Codable, Sendable {
        public let error: NetworkLogger.ResponseError?
        public let metadata: [String: String]?

        public init(error: NetworkLogger.ResponseError? = nil, metadata: [String : String]? = nil) {
            self.error = error
            self.metadata = metadata
        }

        enum CodingKeys: String, CodingKey {
            case error = "3", metadata = "5"
        }
    }
}

#warning("TODO: remove Logger prefix")
/// Indicates current download or upload progress.
public final class LoggerNetworkRequestProgressEntity: NSManagedObject {
    /// Indicates current download or upload progress.
    @NSManaged public var completedUnitCount: Int64
    /// Indicates current download or upload progress.
    @NSManaged public var totalUnitCount: Int64
}

#warning("TODO: move metrics here")
public final class NetworkMetricsEntity: NSManagedObject {
    @NSManaged public var startDate: Date
    @NSManaged public var duration: Double
    @NSManaged public var redirectCount: Int16
    @NSManaged public var transactions: Set<NetworkTransactionMetricsEntity>

    public var taskInterval: DateInterval {
        DateInterval(start: startDate, duration: duration)
    }
}

public final class NetworkTransactionMetricsEntity: NSManagedObject {
    @NSManaged public var index: Int16
    @NSManaged public var rawFetchType: Int16
    @NSManaged public var request: NetworkRequestEntity
    @NSManaged public var response: NetworkResponseEntity?
    @NSManaged public var networkProtocol: String?
    @NSManaged public var localAddress: String?
    @NSManaged public var remoteAddress: String?
    @NSManaged public var localPort: Int32
    @NSManaged public var remotePort: Int32
    @NSManaged public var isProxyConnection: Bool
    @NSManaged public var isReusedConnection: Bool
    @NSManaged public var isCellular: Bool
    @NSManaged public var isExpensive: Bool
    @NSManaged public var isConstrained: Bool
    @NSManaged public var isMultipath: Bool
    @NSManaged public var rawNegotiatedTLSProtocolVersion: Int16
    @NSManaged public var rawNegotiatedTLSCipherSuite: Int16
    @NSManaged public var fetchStartDate: Date?
    @NSManaged public var domainLookupStartDate: Date?
    @NSManaged public var domainLookupEndDate: Date?
    @NSManaged public var connectStartDate: Date?
    @NSManaged public var secureConnectionStartDate: Date?
    @NSManaged public var secureConnectionEndDate: Date?
    @NSManaged public var connectEndDate: Date?
    @NSManaged public var requestStartDate: Date?
    @NSManaged public var requestEndDate: Date?
    @NSManaged public var responseStartDate: Date?
    @NSManaged public var responseEndDate: Date?
    @NSManaged public var requestHeaderBytesSent: Int64
    @NSManaged public var requestBodyBytesBeforeEncoding: Int64
    @NSManaged public var requestBodyBytesSent: Int64
    @NSManaged public var responseHeaderBytesReceived: Int64
    @NSManaged public var responseBodyBytesAfterDecoding: Int64
    @NSManaged public var responseBodyBytesReceived: Int64

    public var fetchType: URLSessionTaskMetrics.ResourceFetchType {
        URLSessionTaskMetrics.ResourceFetchType(rawValue: Int(rawFetchType)) ?? .networkLoad
    }

    public var transferSize: NetworkLogger.TransferSizeInfo {
        var value = NetworkLogger.TransferSizeInfo()
        value.requestHeaderBytesSent = requestHeaderBytesSent
        value.requestBodyBytesBeforeEncoding = requestBodyBytesBeforeEncoding
        value.requestBodyBytesSent = requestBodyBytesSent
        value.responseHeaderBytesReceived = responseHeaderBytesReceived
        value.responseBodyBytesAfterDecoding = responseBodyBytesAfterDecoding
        value.responseBodyBytesReceived = responseBodyBytesReceived
        return value
    }

    public var timing: NetworkLogger.TransactionTimingInfo {
        var value = NetworkLogger.TransactionTimingInfo()
        value.fetchStartDate = fetchStartDate
        value.domainLookupStartDate = domainLookupStartDate
        value.domainLookupEndDate = domainLookupEndDate
        value.connectStartDate = connectStartDate
        value.secureConnectionStartDate = secureConnectionStartDate
        value.secureConnectionEndDate = secureConnectionEndDate
        value.connectEndDate = connectEndDate
        value.requestStartDate = requestStartDate
        value.requestEndDate = requestEndDate
        value.responseStartDate = responseStartDate
        value.responseEndDate = responseEndDate
        return value
    }
}

public final class NetworkRequestEntity: NSManagedObject {
    // MARK: Details

    @NSManaged public var url: String?
    @NSManaged public var httpMethod: String?
    @NSManaged public var httpHeaders: Set<NetworkRequestHeaderEntity>

    // MARK: Options

    @NSManaged public var allowsCellularAccess: Bool
    @NSManaged public var allowsExpensiveNetworkAccess: Bool
    @NSManaged public var allowsConstrainedNetworkAccess: Bool
    @NSManaged public var httpShouldHandleCookies: Bool
    @NSManaged public var httpShouldUsePipelining: Bool
    @NSManaged public var timeoutInterval: Double
    @NSManaged public var rawCachePolicy: UInt16

    public var cachePolicy: URLRequest.CachePolicy {
        URLRequest.CachePolicy(rawValue: UInt(rawCachePolicy)) ?? .useProtocolCachePolicy
    }

    public var contentType: NetworkLogger.ContentType? {
        headers["Content-Type"].flatMap(NetworkLogger.ContentType.init)
    }

    public var headers: [String: String] { httpHeaders.asDictionary() }
}

public final class NetworkRequestHeaderEntity: NSManagedObject {
    @NSManaged public var name: String
    @NSManaged public var value: String
}

#warning("TODO: udpate docc")

extension Set where Element == NetworkRequestHeaderEntity {
    func asDictionary() -> [String: String] {
        var headers: [String: String] = [:]
        for header in self {
            headers[header.name] = header.value
        }
        return headers
    }
}

public final class NetworkResponseEntity: NSManagedObject {
    @NSManaged public var url: String?
    @NSManaged public var statusCode: Int16
    @NSManaged public var httpHeaders: Set<NetworkRequestHeaderEntity>

    public var contentType: NetworkLogger.ContentType? {
        headers["Content-Type"].flatMap(NetworkLogger.ContentType.init)
    }

    public var expectedContentLength: Int64? {
        headers["Content-Length"].flatMap { Int64($0) }
    }

    public var headers: [String: String] { httpHeaders.asDictionary() }
}

/// Doesn't contain any data, just the key and some additional payload.
public final class LoggerBlobHandleEntity: NSManagedObject {
    /// A blob hash (sha1, stored in a binary format).
    @NSManaged public var key: Data

    /// A blob size.
    @NSManaged public var size: Int32

    /// A decompressed blob size.
    @NSManaged public var decompressedSize: Int32

    /// A number of requests referencing it.
    @NSManaged var linkCount: Int16

    /// The logger inlines small blobs in a separate table in the database which
    /// significantly [reduces](https://www.sqlite.org/intern-v-extern-blob.html)
    /// the total allocated size for these files and improves the overall performance.
    ///
    /// The larger blobs are stored in an file system. And when you export a Pulse
    /// document, the larger blobs are read from the created archive on-demand,
    /// significantly reducing the speed with this the documents are opened and
    /// reducing space usage.
    ///
    /// To access data, use the convenience ``data`` property.
    @NSManaged var inlineData: LoggerInlineDataEntity?

    /// Returns the associated data.
    ///
    /// - important: This property only works with `NSManagedObjectContext` instances
    /// created by the ``LoggerStore``. If you are reading the database manually,
    /// you'll need to access the files directly by using the associated ``key``
    /// that matches the name o the file in the `/blobs` directly in the store
    /// directory.
    public var data: Data? {
        guard let store = managedObjectContext?.userInfo[WeakLoggerStore.loggerStoreKey] as? WeakLoggerStore else {
            return nil // Should never happen unless the object was created outside of the LoggerStore moc
        }
        return store.store?.getDecompressedData(for: self)
    }
}

final class LoggerInlineDataEntity: NSManagedObject {
    @NSManaged var data: Data
}
