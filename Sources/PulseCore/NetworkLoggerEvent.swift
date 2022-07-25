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

    public init(urlRequest: URLRequest) {
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

    public init(urlResponse: URLResponse) {
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

    public init(error: Error) {
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
}

public struct NetworkLoggerTransactionMetrics: Codable {
    public let request: NetworkLoggerRequest?
    public let response: NetworkLoggerResponse?
    public let fetchStartDate: Date?
    public let domainLookupStartDate: Date?
    public let domainLookupEndDate: Date?
    public let connectStartDate: Date?
    public let secureConnectionStartDate: Date?
    public let secureConnectionEndDate: Date?
    public let connectEndDate: Date?
    public let requestStartDate: Date?
    public let requestEndDate: Date?
    public let responseStartDate: Date?
    public let responseEndDate: Date?
    public let networkProtocolName: String?
    public let isProxyConnection: Bool
    public let isReusedConnection: Bool
    /// `URLSessionTaskMetrics.ResourceFetchType` enum raw value
    public let resourceFetchType: Int
    public let details: NetworkLoggerTransactionDetailedMetrics?

    public init(metrics: URLSessionTaskTransactionMetrics) {
        self.request = NetworkLoggerRequest(urlRequest: metrics.request)
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
}

public struct NetworkLoggerTransactionDetailedMetrics: Codable {
    public let countOfRequestHeaderBytesSent: Int64
    public let countOfRequestBodyBytesSent: Int64
    public let countOfRequestBodyBytesBeforeEncoding: Int64
    public let countOfResponseHeaderBytesReceived: Int64
    public let countOfResponseBodyBytesReceived: Int64
    public let countOfResponseBodyBytesAfterDecoding: Int64
    public let localAddress: String?
    public let remoteAddress: String?
    public let isCellular: Bool
    public let isExpensive: Bool
    public let isConstrained: Bool
    public let isMultipath: Bool
    public let localPort: Int?
    public let remotePort: Int?
    /// `tls_protocol_version_t` enum raw value
    public let negotiatedTLSProtocolVersion: UInt16?
    /// `tls_ciphersuite_t`  enum raw value
    public let negotiatedTLSCipherSuite: UInt16?

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
