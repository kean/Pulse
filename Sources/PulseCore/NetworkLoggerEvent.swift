// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation

public struct NetworkLoggerRequest: Codable {
    public let url: URL?
    public let httpMethod: String?
    public let headers: [String: String]
    /// `URLRequest.CachePolicy` raw value
    public let cachePolicy: UInt
    public let timeoutInterval: TimeInterval
    public let allowsCellularAccess: Bool
    public let allowsExpensiveNetworkAccess: Bool
    public let allowsConstrainedNetworkAccess: Bool
    public let httpShouldHandleCookies: Bool
    public let httpShouldUsePipelining: Bool

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
}

public struct NetworkLoggerResponse: Codable {
    public let url: String?
    public let statusCode: Int?
    public let contentType: String?
    public let expectedContentLength: Int64?
    public let headers: [String: String]

    public init(_ urlResponse: URLResponse) {
        let httpResponse = urlResponse as? HTTPURLResponse
        self.url = urlResponse.url?.absoluteString
        self.statusCode = httpResponse?.statusCode
        self.contentType = urlResponse.mimeType
        self.expectedContentLength = urlResponse.expectedContentLength
        self.headers = httpResponse?.allHeaderFields as? [String: String] ?? [:]
    }
}

public struct NetworkLoggerError: Codable {
    public let code: Int
    public let domain: String
    public let localizedDescription: String

    public init(_ error: Error) {
        let error = error as NSError
        self.code = error.code
        self.domain = error.domain
        self.localizedDescription = error.localizedDescription
    }
}

public struct NetworkLoggerMetrics: Codable {
    public let taskInterval: DateInterval
    public let redirectCount: Int
    public let transactions: [NetworkLoggerTransactionMetrics]

    public init(metrics: URLSessionTaskMetrics) {
        self.taskInterval = metrics.taskInterval
        self.redirectCount = metrics.redirectCount
        self.transactions = metrics.transactionMetrics.map(NetworkLoggerTransactionMetrics.init)
    }

    public init(taskInterval: DateInterval, redirectCount: Int, transactions: [NetworkLoggerTransactionMetrics]) {
        self.taskInterval = taskInterval
        self.redirectCount = redirectCount
        self.transactions = transactions
    }
}

public struct NetworkLoggerTransactionMetrics: Codable {
    public var request: NetworkLoggerRequest?
    public var response: NetworkLoggerResponse?
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
    public var details: NetworkLoggerTransactionDetailedMetrics?

    public var fetchType: URLSessionTaskMetrics.ResourceFetchType {
        URLSessionTaskMetrics.ResourceFetchType(rawValue: resourceFetchType) ?? .unknown
    }

    public init(metrics: URLSessionTaskTransactionMetrics) {
        self.request = NetworkLoggerRequest(metrics.request)
        self.response = metrics.response.map(NetworkLoggerResponse.init)
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
        self.details = NetworkLoggerTransactionDetailedMetrics(metrics: metrics)
    }

    public init(request: NetworkLoggerRequest? = nil, response: NetworkLoggerResponse? = nil, resourceFetchType: URLSessionTaskMetrics.ResourceFetchType, details: NetworkLoggerTransactionDetailedMetrics? = nil) {
        self.request = request
        self.response = response
        self.resourceFetchType = resourceFetchType.rawValue
        self.details = details
    }
}

public struct NetworkLoggerTransactionDetailedMetrics: Codable {
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

public enum NetworkLoggerTaskType: String, Codable, CaseIterable {
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

private extension URLSessionConfiguration {
    var headers: [String: String]? {
        guard let headers = httpAdditionalHeaders else {
            return nil
        }
        var output: [String: String] = [:]
        for (key, value) in headers {
            output["\(key)"] = "\(value)"
        }
        return output
    }
}
