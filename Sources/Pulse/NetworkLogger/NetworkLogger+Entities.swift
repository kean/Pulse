// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation

extension NetworkLogger {
    public struct Request: Hashable, Codable, Sendable {
        public var url: URL?
        public var httpMethod: String?
        public var headers: [String: String]?
        public var cachePolicy: URLRequest.CachePolicy {
            rawCachePolicy.flatMap(URLRequest.CachePolicy.init) ?? .useProtocolCachePolicy
        }
        public var timeout: TimeInterval
        public var options: Options

        public var contentType: ContentType? {
            headers?["Content-Type"].flatMap(ContentType.init)
        }

        private var rawCachePolicy: UInt?

        public struct Options: OptionSet, Hashable, Codable, Sendable {
            public let rawValue: Int8
            public init(rawValue: Int8) { self.rawValue = rawValue }

            public static let allowsCellularAccess = Options(rawValue: 1 << 0)
            public static let allowsExpensiveNetworkAccess = Options(rawValue: 1 << 1)
            public static let allowsConstrainedNetworkAccess = Options(rawValue: 1 << 2)
            public static let httpShouldHandleCookies = Options(rawValue: 1 << 3)
            public static let httpShouldUsePipelining = Options(rawValue: 1 << 4)

            init(_ request: URLRequest) {
                self = []
                if request.allowsCellularAccess { insert(.allowsCellularAccess) }
                if request.allowsExpensiveNetworkAccess { insert(.allowsExpensiveNetworkAccess) }
                if request.allowsConstrainedNetworkAccess { insert(.allowsConstrainedNetworkAccess) }
                if request.httpShouldHandleCookies { insert(.httpShouldHandleCookies) }
                if request.httpShouldUsePipelining { insert(.httpShouldUsePipelining) }
            }
            
            init(_ entity: NetworkRequestEntity) {
                self = []
                if entity.allowsCellularAccess { insert(.allowsCellularAccess) }
                if entity.allowsExpensiveNetworkAccess { insert(.allowsExpensiveNetworkAccess) }
                if entity.allowsConstrainedNetworkAccess { insert(.allowsConstrainedNetworkAccess) }
                if entity.httpShouldHandleCookies { insert(.httpShouldHandleCookies) }
                if entity.httpShouldUsePipelining { insert(.httpShouldUsePipelining) }
            }
        }

        public init(_ urlRequest: URLRequest) {
            self.url = urlRequest.url
            self.headers = urlRequest.allHTTPHeaderFields
            self.httpMethod = urlRequest.httpMethod
            self.rawCachePolicy = urlRequest.cachePolicy.rawValue
            self.timeout = urlRequest.timeoutInterval
            self.options = Options(urlRequest)
        }
        
        init(_ entity: NetworkRequestEntity) {
            self.url = entity.url.flatMap(URL.init)
            self.httpMethod = entity.httpMethod
            self.headers = entity.headers
            self.rawCachePolicy = UInt(entity.rawCachePolicy)
            self.timeout = TimeInterval(entity.timeoutInterval)
            self.options = Options(entity)
        }
    }

    public struct Response: Hashable, Codable, Sendable {
        public var statusCode: Int?
        public var headers: [String: String]?

        public var contentType: ContentType? {
            headers?["Content-Type"].flatMap(ContentType.init)
        }

        var isSuccess: Bool {
            // By default, use 200 for non-HTTP responses
            (100..<400).contains(statusCode ?? 200)
        }

        public init(_ urlResponse: URLResponse) {
            let httpResponse = urlResponse as? HTTPURLResponse
            self.statusCode = httpResponse?.statusCode
            self.headers = httpResponse?.allHeaderFields as? [String: String]
        }
        
        init(_ entity: NetworkResponseEntity) {
            self.statusCode = Int(entity.statusCode)
            self.headers = entity.headers
        }
    }

    public struct ResponseError: Codable, Sendable {
        public var code: Int
        public var domain: String
        public var debugDescription: String
        /// Contains the underlying error.
        ///
        /// - note: Currently is only used for ``NetworkLogger/DecodingError``.
        public var error: Swift.Error? { underlyingError?.error }

        var underlyingError: UnderlyingError?

        public init(_ error: Swift.Error) {
            let error = error as NSError
            self.code = error.code == 0 ? -1 : error.code
            if error is Swift.DecodingError || error is NetworkLogger.DecodingError {
                self.domain = NetworkLogger.DecodingError.domain
            } else {
                self.domain = error.domain
            }
            self.underlyingError = UnderlyingError(error)
            // NetworkLogger.DecodingError has a custom description
            if let error = underlyingError?.error {
                self.debugDescription = (error as NSError).debugDescription
            } else {
                self.debugDescription = error.debugDescription
            }
        }

        enum UnderlyingError: Codable, Sendable {
            case decodingError(NetworkLogger.DecodingError)

            var error: Error? {
                switch self {
                case .decodingError(let error): return error
                }
            }

            init?(_ error: Error) {
                if let error = error as? Swift.DecodingError {
                    self = .decodingError(.init(error))
                } else if let error = error as? NetworkLogger.DecodingError {
                    self = .decodingError(error)
                } else {
                    return nil
                }
            }
        }
    }

    public struct Metrics: Codable, Sendable {
        public var taskInterval: DateInterval
        public var redirectCount: Int
        public var transactions: [TransactionMetrics]
        public var totalTransferSize: TransferSizeInfo { TransferSizeInfo(metrics: self) }

        public init(metrics: URLSessionTaskMetrics) {
            self.taskInterval = metrics.taskInterval
            self.redirectCount = metrics.redirectCount
            self.transactions = metrics.transactionMetrics.map(TransactionMetrics.init)
        }

        public init(taskInterval: DateInterval, redirectCount: Int, transactions: [TransactionMetrics]) {
            self.taskInterval = taskInterval
            self.redirectCount = redirectCount
            self.transactions = transactions
        }
    }

    public struct TransferSizeInfo: Codable, Sendable {
        // MARK: Sent
        public var totalBytesSent: Int64 { requestBodyBytesSent + requestHeaderBytesSent }
        public var requestHeaderBytesSent: Int64 = 0
        public var requestBodyBytesBeforeEncoding: Int64 = 0
        public var requestBodyBytesSent: Int64 = 0

        // MARK: Received
        public var totalBytesReceived: Int64 { responseBodyBytesReceived + responseHeaderBytesReceived }
        public var responseHeaderBytesReceived: Int64 = 0
        public var responseBodyBytesAfterDecoding: Int64 = 0
        public var responseBodyBytesReceived: Int64 = 0

        public init() {}

        public init(metrics: Metrics) {
            var size = TransferSizeInfo()
            for transaction in metrics.transactions {
                size = size.merging(transaction.transferSize)
            }
            self = size
        }

        init(metrics: URLSessionTaskTransactionMetrics) {
            requestHeaderBytesSent = metrics.countOfRequestHeaderBytesSent
            requestBodyBytesBeforeEncoding = metrics.countOfRequestBodyBytesBeforeEncoding
            requestBodyBytesSent = metrics.countOfRequestBodyBytesSent
            responseHeaderBytesReceived = metrics.countOfResponseHeaderBytesReceived
            responseBodyBytesReceived = metrics.countOfResponseBodyBytesReceived
            responseBodyBytesAfterDecoding = metrics.countOfResponseBodyBytesAfterDecoding
        }

        public func merging(_ size: TransferSizeInfo) -> TransferSizeInfo {
            var size = size
            // Using overflow operators just in case
            size.requestHeaderBytesSent &+= requestHeaderBytesSent
            size.requestBodyBytesBeforeEncoding &+= requestBodyBytesBeforeEncoding
            size.requestBodyBytesSent &+= requestBodyBytesSent
            size.responseHeaderBytesReceived &+= responseHeaderBytesReceived
            size.responseBodyBytesAfterDecoding &+= responseBodyBytesAfterDecoding
            size.responseBodyBytesReceived &+= responseBodyBytesReceived
            return size
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let values = try container.decode([Int64].self)
            guard values.count >= 6 else {
                throw Swift.DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid transfer size info")
            }
            (requestHeaderBytesSent, requestBodyBytesBeforeEncoding, requestBodyBytesSent, responseHeaderBytesReceived, responseBodyBytesReceived, responseBodyBytesAfterDecoding) = (values[0], values[1], values[2], values[3], values[4], values[5])
        }

        /// Just a space and compile time optimization
        public func encode(to encoder: Encoder) throws {
            try [requestHeaderBytesSent, requestBodyBytesBeforeEncoding, requestBodyBytesSent, responseHeaderBytesReceived, responseBodyBytesReceived, responseBodyBytesAfterDecoding].encode(to: encoder)
        }
    }

    public struct TransactionMetrics: Codable, Sendable {
        public var fetchType: URLSessionTaskMetrics.ResourceFetchType {
            type.flatMap(URLSessionTaskMetrics.ResourceFetchType.init) ?? .networkLoad
        }
        public var request: Request
        public var response: Response?
        public var timing: TransactionTimingInfo
        public var networkProtocol: String?
        public var transferSize: TransferSizeInfo
        public var conditions: Conditions
        public var localAddress: String?
        public var remoteAddress: String?
        public var localPort: Int?
        public var remotePort: Int?
        public var negotiatedTLSProtocolVersion: tls_protocol_version_t? {
            tlsVersion.flatMap(tls_protocol_version_t.init)
        }
        public var negotiatedTLSCipherSuite: tls_ciphersuite_t? {
            tlsSuite.flatMap(tls_ciphersuite_t.init)
        }

        private var tlsVersion: UInt16?
        private var tlsSuite: UInt16?
        private var type: Int?

        public init(metrics: URLSessionTaskTransactionMetrics) {
            self.request = Request(metrics.request)
            self.response = metrics.response.map(Response.init)
            self.timing = TransactionTimingInfo(metrics: metrics)
            self.networkProtocol = metrics.networkProtocolName
            self.type = (metrics.resourceFetchType == .networkLoad ? nil :  metrics.resourceFetchType.rawValue)
            self.transferSize = TransferSizeInfo(metrics: metrics)
            self.conditions = Conditions(metrics: metrics)
            self.localAddress = metrics.localAddress
            self.remoteAddress = metrics.remoteAddress
            self.localPort = metrics.localPort
            self.remotePort = metrics.remotePort
            self.tlsVersion = metrics.negotiatedTLSProtocolVersion?.rawValue
            self.tlsSuite = metrics.negotiatedTLSCipherSuite?.rawValue
        }

        public init(request: Request, response: Response? = nil, resourceFetchType: URLSessionTaskMetrics.ResourceFetchType) {
            self.request = request
            self.response = response
            self.timing = .init()
            self.type = resourceFetchType.rawValue
            self.transferSize = .init()
            self.conditions = []
        }

        public struct Conditions: OptionSet, Codable, Sendable {
            public let rawValue: Int8
            public init(rawValue: Int8) { self.rawValue = rawValue }

            public static let isProxyConnection = Conditions(rawValue: 1 << 0)
            public static let isReusedConnection = Conditions(rawValue: 1 << 1)
            public static let isCellular = Conditions(rawValue: 1 << 2)
            public static let isExpensive = Conditions(rawValue: 1 << 3)
            public static let isConstrained = Conditions(rawValue: 1 << 4)
            public static let isMultipath = Conditions(rawValue: 1 << 5)

            init(metrics: URLSessionTaskTransactionMetrics) {
                self = []
                if metrics.isProxyConnection { insert(.isProxyConnection) }
                if metrics.isReusedConnection { insert(.isReusedConnection) }
                if metrics.isCellular { insert(.isCellular) }
                if metrics.isExpensive { insert(.isExpensive) }
                if metrics.isConstrained { insert(.isConstrained) }
                if metrics.isMultipath { insert(.isMultipath) }
            }
            
            init(_ entity: NetworkTransactionMetricsEntity) {
                self = []
                if entity.isProxyConnection { insert(.isProxyConnection) }
                if entity.isReusedConnection { insert(.isReusedConnection) }
                if entity.isCellular { insert(.isCellular) }
                if entity.isExpensive { insert(.isExpensive) }
                if entity.isConstrained { insert(.isConstrained) }
                if entity.isMultipath { insert(.isMultipath) }
            }
        }
        
        init(_ entity: NetworkTransactionMetricsEntity) {
            self.request = NetworkLogger.Request(entity.request)
            self.response = entity.response.map(NetworkLogger.Response.init)
            self.timing = entity.timing
            self.networkProtocol = entity.networkProtocol
            self.transferSize = entity.transferSize
            self.conditions = Conditions(entity)
            self.localAddress = entity.localAddress
            self.localPort = Int(entity.localPort)
            self.remoteAddress = entity.remoteAddress
            self.remotePort = Int(entity.remotePort)
            self.tlsVersion = UInt16(entity.rawNegotiatedTLSProtocolVersion)
            self.tlsSuite = UInt16(entity.rawNegotiatedTLSCipherSuite)
            self.type = Int(entity.rawFetchType)
        }
    }

    public struct TransactionTimingInfo: Codable, Sendable {
        public var fetchStartDate: Date?
        public var domainLookupStartDate: Date?
        public var domainLookupEndDate: Date?
        public var connectStartDate: Date?
        public var secureConnectionStartDate: Date?
        public var secureConnectionEndDate: Date?
        public var connectEndDate: Date?
        public var requestStartDate: Date?
        public var requestEndDate: Date?
        public var responseStartDate: Date?
        public var responseEndDate: Date?

        public var duration: TimeInterval? {
            guard let startDate = fetchStartDate, let endDate = responseEndDate else {
                return nil
            }
            return max(0, endDate.timeIntervalSince(startDate))
        }

        public init(metrics: URLSessionTaskTransactionMetrics) {
            self.fetchStartDate = metrics.fetchStartDate
            self.domainLookupStartDate = metrics.domainLookupStartDate
            self.domainLookupEndDate = metrics.domainLookupEndDate
            self.connectStartDate = metrics.connectStartDate
            self.secureConnectionStartDate = metrics.secureConnectionStartDate
            self.secureConnectionEndDate = metrics.secureConnectionEndDate
            self.connectEndDate = metrics.connectEndDate
            self.requestStartDate = metrics.requestStartDate
            self.requestEndDate = metrics.requestEndDate
            self.responseStartDate = metrics.responseStartDate
            self.responseEndDate = metrics.responseEndDate
        }

        public init() {}

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let values = try container.decode([Date?].self)
            guard values.count >= 11 else {
                throw Swift.DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid transfer size info")
            }
            (fetchStartDate, domainLookupStartDate, domainLookupEndDate, connectStartDate, secureConnectionStartDate, secureConnectionEndDate, connectEndDate, requestStartDate, requestEndDate, responseStartDate, responseEndDate) = (values[0], values[1], values[2], values[3], values[4], values[5], values[6], values[7], values[8], values[9], values[10])
        }

        /// Just a space and compile time optimization
        public func encode(to encoder: Encoder) throws {
            try [fetchStartDate, domainLookupStartDate, domainLookupEndDate, connectStartDate, secureConnectionStartDate, secureConnectionEndDate, connectEndDate, requestStartDate, requestEndDate, responseStartDate, responseEndDate].encode(to: encoder)
        }
    }

    @frozen public enum TaskType: Int16, Codable, CaseIterable, Sendable {
        case dataTask
        case downloadTask
        case uploadTask
        case streamTask
        case webSocketTask

        public init(task: URLSessionTask) {
            switch task {
            case is URLSessionUploadTask: self = .uploadTask
            case is URLSessionDataTask: self = .dataTask
            case is URLSessionDownloadTask: self = .downloadTask
            case is URLSessionStreamTask: self = .streamTask
            case is URLSessionWebSocketTask: self = .webSocketTask
            default: self = .dataTask
            }
        }

        public var urlSessionTaskClassName: String {
            switch self {
            case .dataTask: return "URLSessionDataTask"
            case .downloadTask: return "URLSessionDownloadTask"
            case .streamTask: return "URLSessionStreamTask"
            case .uploadTask: return "URLSessionUploadTask"
            case .webSocketTask: return "URLSessionWebSocketTask"
            }
        }
    }

    public enum DecodingError: Error, Codable, CustomDebugStringConvertible, Sendable {
        case typeMismatch(type: String, context: Context)
        case valueNotFound(type: String, context: Context)
        case keyNotFound(codingKey: CodingKey, context: Context)
        case dataCorrupted(context: Context)
        case unknown

        public static let domain = "DecodingError"

        public struct Context: Codable, CustomDebugStringConvertible, Sendable {
            public var codingPath: [CodingKey]
            public var debugDescription: String

            public init(_ context: Swift.DecodingError.Context) {
                self.codingPath = context.codingPath.map(CodingKey.init)
                self.debugDescription = context.debugDescription.trimmingCharacters(in: .punctuationCharacters)
            }

            public init(codingPath: [CodingKey], debugDescription: String) {
                self.codingPath = codingPath
                self.debugDescription = debugDescription
            }

            var formattedPath: String {
                codingPath.map(\.debugDescription).joined(separator: ".")
            }
        }

        public enum CodingKey: Codable, Hashable, CustomDebugStringConvertible, Sendable {
            case string(String)
            case int(Int)

            public init(_ key: Swift.CodingKey) {
                if let value = key.intValue {
                    self = .int(value)
                } else {
                    self = .string(key.stringValue)
                }
            }

            public var debugDescription: String {
                switch self {
                case .string(let value): return "\(value)"
                case .int(let value): return "\(value)"
                }
            }
        }

        public init(_ error: Swift.DecodingError) {
            switch error {
            case let .typeMismatch(type, context):
                self = .typeMismatch(type: String(describing: type), context: .init(context))
            case let .valueNotFound(type, context):
                self = .valueNotFound(type: String(describing: type), context: .init(context))
            case let .keyNotFound(codingKey, context):
                self = .keyNotFound(codingKey: .init(codingKey), context: .init(context))
            case let .dataCorrupted(context):
                self = .dataCorrupted(context: .init(context))
            @unknown default:
                self = .unknown
            }
        }

        public var context: Context? {
            switch self {
            case .typeMismatch(_, let context): return context
            case .valueNotFound(_, let context): return context
            case .keyNotFound(_, let context): return context
            case .dataCorrupted(let context): return context
            case .unknown: return nil
            }
        }

        public var debugDescription: String {
            switch self {
            case .typeMismatch(let type, let context):
                return "DecodingError.typeMismatch(type: \"\(type)\", path: \"\(context.formattedPath)\", \"\(context.debugDescription)\")"
            case .valueNotFound(let type, let context):
                return "DecodingError.valueNotFound(type: \"\(type)\", path: \"\(context.formattedPath)\", \"\(context.debugDescription)\")"
            case .keyNotFound(let codingKey, let context):
                return "DecodingError.keyNotFound(key: \"\(codingKey.debugDescription)\", path: \"\(context.formattedPath)\", \"\(context.debugDescription)\")"
            case .dataCorrupted(let context):
                return "DecodingError.dataCorrupted(path: \(context.formattedPath), \"\(context.debugDescription)\")"
            case .unknown:
                return "DecodingError.unknown"
            }
        }
    }

    public struct ContentType: Hashable, ExpressibleByStringLiteral {
        /// The type and subtype of the content type. This is everything except for
        /// any parameters that are also attached.
        public var type: String

        /// Key/Value pairs serialized as parameters for the content type.
        ///
        /// For example, in "`text/plain; charset=UTF-8`" "charset" is
        /// the name of a parameter with the value "UTF-8".
        public var parameters: [String: String]

        public var rawValue: String

        public init?(rawValue: String) {
            let parts = rawValue.split(separator: ";")
            guard let type = parts.first else { return nil }
            self.type = type.lowercased()
            var parameters: [String: String] = [:]
            for (key, value) in parts.dropFirst().compactMap(parseParameter) {
                parameters[key] = value
            }
            self.parameters = parameters
            self.rawValue = rawValue
        }

        public static let any = ContentType(rawValue: "*/*")!

        public init(stringLiteral value: String) {
            self = ContentType(rawValue: value) ?? .any
        }

        public var isJSON: Bool { type.contains("json") }
        public var isPDF: Bool { type.contains("pdf") }
        public var isImage: Bool { type.hasPrefix("image/") }
        public var isHTML: Bool { type.contains("html") }
        public var isEncodedForm: Bool { type == "application/x-www-form-urlencoded" }
    }
}

private func parseParameter(_ param: Substring) -> (String, String)? {
    let parts = param.split(separator: "=")
    guard parts.count == 2, let name = parts.first, let value = parts.last else {
        return nil
    }
    return (name.trimmingCharacters(in: .whitespaces), value.trimmingCharacters(in: .whitespaces))
}
