// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation

extension URLSession: URLSessionProtocol {}

extension NetworkLogger {
    public final class URLSessionProxy {
        let session: URLSession
        var logger: NetworkLogger { _logger ?? .shared}
        private var _logger: NetworkLogger?

        public init(session: URLSession, logger: NetworkLogger? = nil) {
            self.session = session
            self._logger = logger
        }
    }
}

extension NetworkLogger.URLSessionProxy: URLSessionProtocol {
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        fatalError("Not implemented")
    }

    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public func data(from url: URL) async throws -> (Data, URLResponse) {
        fatalError("Not implemented")
    }

    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public func upload(for request: URLRequest, fromFile fileURL: URL) async throws -> (Data, URLResponse) {
        fatalError("Not implemented")
    }

    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public func upload(for request: URLRequest, from bodyData: Data) async throws -> (Data, URLResponse) {
        fatalError("Not implemented")
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    public func data(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse) {
        let delegate = URLSessionProxyDelegate(logger: logger, delegate: delegate)
        do {
            let (data, response) = try await session.data(for: request, delegate: delegate)
            if let task = delegate.createdTask as? URLSessionDataTask {
                logger.logDataTask(task, didReceive: data)
                logger.logTask(task, didCompleteWithError: nil)
            }
            return (data, response)
        } catch {
            if let task = delegate.createdTask {
                logger.logTask(task, didCompleteWithError: error)
            }
            throw error
        }
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    public func data(from url: URL, delegate: (any URLSessionTaskDelegate)? = nil) async throws -> (Data, URLResponse) {
        try await data(for: URLRequest(url: url), delegate: delegate)
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    public func upload(for request: URLRequest, fromFile fileURL: URL, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse) {
        fatalError("Not implemented")
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    public func upload(for request: URLRequest, from bodyData: Data, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse) {
        fatalError("Not implemented")
    }
}


// Enable remote logger features (required for Pulse Pro)
//let configuration = URLSessionConfiguration.default
//configuration.protocolClasses = [RemoteLoggerURLProtocol.self]
//
//
//// Enable capturing of network traffic using a proxy delegate.
//let session = URLSession(
//    configuration: configuration,
//    delegate: URLSessionProxyDelegate(delegate: <#ActualDelegate#>),
//    delegateQueue: nil
//)
