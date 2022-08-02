// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation

extension NetworkLogger {
    public struct Request: Codable, Sendable {
        public var url: URL?
        public var httpMethod: String?
        public var headers: [String: String]
        /// `URLRequest.CachePolicy` raw value
        public var cachePolicy: UInt
        public var timeoutInterval: TimeInterval
        public var allowsCellularAccess: Bool
        public var allowsExpensiveNetworkAccess: Bool
        public var allowsConstrainedNetworkAccess: Bool
        public var httpShouldHandleCookies: Bool
        public var httpShouldUsePipelining: Bool

        public init(_ urlRequest: URLRequest) {
            self.url = urlRequest.url
            self.httpMethod = urlRequest.httpMethod
            self.headers = urlRequest.allHTTPHeaderFields ?? [:]
            self.cachePolicy = urlRequest.cachePolicy.rawValue
            self.timeoutInterval = urlRequest.timeoutInterval
            self.allowsCellularAccess = urlRequest.allowsCellularAccess
            self.allowsExpensiveNetworkAccess = urlRequest.allowsExpensiveNetworkAccess
            self.allowsConstrainedNetworkAccess = urlRequest.allowsConstrainedNetworkAccess
            self.httpShouldHandleCookies = urlRequest.httpShouldHandleCookies
            self.httpShouldUsePipelining = urlRequest.httpShouldUsePipelining
        }

        /// Redacts values for the provided headers.
        public func redactingSensitiveHeaders(_ redactedHeaders: Set<String>) -> Request {
            var copy = self
            copy.headers = _redactingSensitiveHeaders(redactedHeaders, from: self.headers)
            return copy
        }
    }

    public struct Response: Codable, Sendable {
        public var url: String?
        public var statusCode: Int?
        public var contentType: String?
        public var expectedContentLength: Int64?
        public var headers: [String: String]

        public init(_ urlResponse: URLResponse) {
            let httpResponse = urlResponse as? HTTPURLResponse
            self.url = urlResponse.url?.absoluteString
            self.statusCode = httpResponse?.statusCode
            self.contentType = urlResponse.mimeType
            self.expectedContentLength = urlResponse.expectedContentLength
            self.headers = httpResponse?.allHeaderFields as? [String: String] ?? [:]
        }

        /// Redacts values for the provided headers.
        public func redactingSensitiveHeaders(_ redactedHeaders: Set<String>) -> Response {
            var copy = self
            copy.headers = _redactingSensitiveHeaders(redactedHeaders, from: self.headers)
            return copy
        }
    }

    public struct ResponseError: Codable, Sendable {
        public var code: Int
        public var domain: String
        public var debugDescription: String
        /// Contains the underlying error.
        ///
        /// - note: Currently is only used for ``NetworkLogger/DecodingError``.
        public var error: Error?

        public init(_ error: Error) {
            let error = error as NSError
            self.code = error.code == 0 ? -1 : error.code
            if error is DecodingError || error is NetworkLogger.DecodingError {
                self.domain = NetworkLogger.DecodingError.domain
            } else {
                self.domain = error.domain
            }
            self.debugDescription = String(describing: error)
            self.error = error
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.code = try container.decode(Int.self, forKey: .code)
            self.domain = try container.decode(String.self, forKey: .domain)
            self.debugDescription = (try? container.decode(String.self, forKey: .debugDescription)) ?? "–"
            self.error = (try? container.decode(UnderlyingError.self, forKey: .error))?.error
        }

        public enum CodingKeys: CodingKey {
            case code, domain, debugDescription, error
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(code, forKey: .code)
            try container.encode(domain, forKey: .domain)
            try container.encode(debugDescription, forKey: .debugDescription)
            try? container.encode(error.map(UnderlyingError.init), forKey: .error)
        }

        private enum UnderlyingError: Codable, Sendable {
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
        public var transactions: [NetworkLogger.TransactionMetrics]
        public var transferSize: TransferSizeInfo { TransferSizeInfo(metrics: self) }

        public init(metrics: URLSessionTaskMetrics) {
            self.taskInterval = metrics.taskInterval
            self.redirectCount = metrics.redirectCount
            self.transactions = metrics.transactionMetrics.map(NetworkLogger.TransactionMetrics.init)
        }

        public init(taskInterval: DateInterval, redirectCount: Int, transactions: [NetworkLogger.TransactionMetrics]) {
            self.taskInterval = taskInterval
            self.redirectCount = redirectCount
            self.transactions = transactions
        }

        /// Total transfer size across all transactions.
        public struct TransferSizeInfo: Sendable {
            public var totalBytesSent: Int64 = 0
            public var bodyBytesSent: Int64 = 0
            public var headersBytesSent: Int64 = 0
            public var totalBytesReceived: Int64 = 0
            public var bodyBytesReceived: Int64 = 0
            public var headersBytesReceived: Int64 = 0

            public init() {}

            public init(metrics: NetworkLogger.Metrics) {
                for details in metrics.transactions.compactMap(\.details) {
                    totalBytesSent += details.countOfRequestBodyBytesBeforeEncoding + details.countOfRequestHeaderBytesSent
                    bodyBytesSent += details.countOfRequestBodyBytesSent
                    headersBytesSent += details.countOfRequestHeaderBytesSent
                    totalBytesReceived += details.countOfResponseBodyBytesReceived + details.countOfResponseHeaderBytesReceived
                    bodyBytesReceived += details.countOfResponseBodyBytesReceived
                    headersBytesReceived += details.countOfResponseHeaderBytesReceived
                }
            }

            public func merging(_ size: TransferSizeInfo) -> TransferSizeInfo {
                var size = size
                size.totalBytesSent += totalBytesSent
                size.bodyBytesSent += bodyBytesSent
                size.headersBytesSent += headersBytesSent
                size.totalBytesReceived += totalBytesReceived
                size.bodyBytesReceived += bodyBytesReceived
                size.headersBytesReceived += headersBytesReceived
                return size
            }
        }
    }

    public struct TransactionMetrics: Codable, Sendable {
        public var request: NetworkLogger.Request?
        public var response: NetworkLogger.Response?
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
        public var networkProtocolName: String?
        public var isProxyConnection = false
        public var isReusedConnection = false
        /// `URLSessionTaskMetrics.ResourceFetchType` enum raw value
        public var resourceFetchType: Int
        public var details: NetworkLogger.TransactionDetailedMetrics?

        public var fetchType: URLSessionTaskMetrics.ResourceFetchType {
            URLSessionTaskMetrics.ResourceFetchType(rawValue: resourceFetchType) ?? .unknown
        }

        public var duration: TimeInterval? {
            guard let startDate = fetchStartDate, let endDate = responseEndDate else {
                return nil
            }
            return max(0, endDate.timeIntervalSince(startDate))
        }

        public init(metrics: URLSessionTaskTransactionMetrics) {
            self.request = NetworkLogger.Request(metrics.request)
            self.response = metrics.response.map(NetworkLogger.Response.init)
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
            self.networkProtocolName = metrics.networkProtocolName
            self.isProxyConnection = metrics.isProxyConnection
            self.isReusedConnection = metrics.isReusedConnection
            self.resourceFetchType = metrics.resourceFetchType.rawValue
            self.details = NetworkLogger.TransactionDetailedMetrics(metrics: metrics)
        }

        public init(request: NetworkLogger.Request? = nil, response: NetworkLogger.Response? = nil, resourceFetchType: URLSessionTaskMetrics.ResourceFetchType, details: NetworkLogger.TransactionDetailedMetrics? = nil) {
            self.request = request
            self.response = response
            self.resourceFetchType = resourceFetchType.rawValue
            self.details = details
        }
    }

    public struct TransactionDetailedMetrics: Codable, Sendable {
        public var countOfRequestHeaderBytesSent: Int64 = 0
        public var countOfRequestBodyBytesSent: Int64 = 0
        public var countOfRequestBodyBytesBeforeEncoding: Int64 = 0
        public var countOfResponseHeaderBytesReceived: Int64 = 0
        public var countOfResponseBodyBytesReceived: Int64 = 0
        public var countOfResponseBodyBytesAfterDecoding: Int64 = 0
        public var localAddress: String?
        public var remoteAddress: String?
        public var isCellular = false
        public var isExpensive = false
        public var isConstrained = false
        public var isMultipath = false
        public var localPort: Int?
        public var remotePort: Int?
        /// `tls_protocol_version_t` enum raw value
        public var negotiatedTLSProtocolVersion: UInt16?
        /// `tls_ciphersuite_t`  enum raw value
        public var negotiatedTLSCipherSuite: UInt16?

        public init(metrics: URLSessionTaskTransactionMetrics) {
            self.countOfRequestHeaderBytesSent = metrics.countOfRequestHeaderBytesSent
            self.countOfRequestBodyBytesSent = metrics.countOfRequestBodyBytesSent
            self.countOfRequestBodyBytesBeforeEncoding = metrics.countOfRequestBodyBytesBeforeEncoding
            self.countOfResponseHeaderBytesReceived = metrics.countOfResponseHeaderBytesReceived
            self.countOfResponseBodyBytesReceived = metrics.countOfResponseBodyBytesReceived
            self.countOfResponseBodyBytesAfterDecoding = metrics.countOfResponseBodyBytesAfterDecoding
            self.localAddress = metrics.localAddress
            self.remoteAddress = metrics.remoteAddress
            self.isCellular = metrics.isCellular
            self.isExpensive = metrics.isExpensive
            self.isConstrained = metrics.isConstrained
            self.isMultipath = metrics.isMultipath
            self.localPort = metrics.localPort
            self.remotePort = metrics.remotePort
            self.negotiatedTLSProtocolVersion = metrics.negotiatedTLSProtocolVersion?.rawValue
            self.negotiatedTLSCipherSuite = metrics.negotiatedTLSCipherSuite?.rawValue
        }

        public init() {}
    }

    public enum TaskType: String, Codable, CaseIterable, Sendable {
        case dataTask = "data"
        case downloadTask = "download"
        case uploadTask = "upload"
        case streamTask = "stream"
        case webSocketTask = "websocket"

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

    public enum DecodingError: Error, Codable, Sendable {
        case typeMismatch(type: String, context: Context)
        case valueNotFound(type: String, context: Context)
        case keyNotFound(codingKey: CodingKey, context: Context)
        case dataCorrupted(context: Context)
        case unknown

        public static let domain = "DecodingError"

        public struct Context: Codable, Sendable {
            public var codingPath: [CodingKey]
            public var debugDescription: String

            public init(_ context: Swift.DecodingError.Context) {
                self.codingPath = context.codingPath.map(CodingKey.init)
                self.debugDescription = context.debugDescription
            }

            public init(codingPath: [CodingKey], debugDescription: String) {
                self.codingPath = codingPath
                self.debugDescription = debugDescription
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
                case .string(let value): return "CodingKey.string(\"\(value)\")"
                case .int(let value): return "CodingKey.int(\(value))"
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

private func _redactingSensitiveHeaders(_ redactedHeaders: Set<String>, from headers: [String: String]) -> [String: String] {
    var newHeaders: [String: String] = [:]
    let redactedHeaders = Set(redactedHeaders.map { $0.lowercased() })
    for (key, value) in headers {
        if redactedHeaders.contains(key.lowercased()) {
            newHeaders[key] = "<private>"
        } else {
            newHeaders[key] = value
        }
    }
    return newHeaders
}
