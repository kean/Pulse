// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation

extension NetworkLogger {
    /// A configuration object that defines session behavior.
    public struct URLSessionOptions: Sendable {
        /// If enabled, registers ``RemoteLoggerURLProtocol``
        public var isMockingEnabled = true

        /// A custom logger to be used instead of ``NetworkLogger/shared``.
        public var logger: NetworkLogger?

        /// Creates default options.
        public init() {}
    }

    public final class URLSession {
        /// The underlying `URLSession`.
        public let session: Foundation.URLSession
        var logger: NetworkLogger { options.logger ?? .shared}
        private let options: URLSessionOptions

        public convenience init(
            configuration: URLSessionConfiguration,
            options: URLSessionOptions = .init()
        ) {
            self.init(configuration: configuration, delegate: nil, delegateQueue: nil, options: options)
        }

        public init(
            configuration: URLSessionConfiguration,
            delegate: (any URLSessionDelegate)?,
            delegateQueue: OperationQueue? = nil,
            options: URLSessionOptions = .init()
        ) {
            if options.isMockingEnabled {
                configuration.protocolClasses = [RemoteLoggerURLProtocol.self] + (configuration.protocolClasses ?? [])
            }
            self.session = Foundation.URLSession(
                configuration: configuration,
                delegate: URLSessionProxyDelegate(logger: options.logger, delegate: delegate),
                delegateQueue: delegateQueue
            )
            self.options = options
        }
    }
}

extension NetworkLogger.URLSession: URLSessionProtocol {
    public var sessionDescription: String? {
        get { session.sessionDescription }
        set { session.sessionDescription = newValue }
    }

    public func finishTasksAndInvalidate() {
        session.finishTasksAndInvalidate()
    }

    public func invalidateAndCancel() {
        session.invalidateAndCancel()
    }

    public func dataTask(with request: URLRequest) -> URLSessionDataTask {
        session.dataTask(with: request)
    }

    public func dataTask(with url: URL) -> URLSessionDataTask {
        session.dataTask(with: url)
    }

    public func uploadTask(with request: URLRequest, from bodyData: Data) -> URLSessionUploadTask {
        session.uploadTask(with: request, from: bodyData)
    }

    public func uploadTask(with request: URLRequest, fromFile fileURL: URL) -> URLSessionUploadTask {
        session.uploadTask(with: request, fromFile: fileURL)
    }

    @available(iOS 17, tvOS 17, macOS 14, watchOS 9, *)
    public func uploadTask(withResumeData resumeData: Data) -> URLSessionUploadTask {
        session.uploadTask(withResumeData: resumeData)
    }

    public func uploadTask(withStreamedRequest request: URLRequest) -> URLSessionUploadTask {
        session.uploadTask(withStreamedRequest: request)
    }

    public func downloadTask(with request: URLRequest) -> URLSessionDownloadTask {
        session.downloadTask(with: request)
    }

    public func downloadTask(with url: URL) -> URLSessionDownloadTask {
        session.downloadTask(with: url)
    }

    public func downloadTask(withResumeData resumeData: Data) -> URLSessionDownloadTask {
        session.downloadTask(withResumeData: resumeData)
    }

    public func streamTask(withHostName hostname: String, port: Int) -> URLSessionStreamTask {
        session.streamTask(withHostName: hostname, port: port)
    }

    public func webSocketTask(with url: URL) -> URLSessionWebSocketTask {
        session.webSocketTask(with: url)
    }

    public func webSocketTask(with url: URL, protocols: [String]) -> URLSessionWebSocketTask {
        session.webSocketTask(with: url, protocols: protocols)
    }

    public func webSocketTask(with request: URLRequest) -> URLSessionWebSocketTask {
        session.webSocketTask(with: request)
    }

    // MARK: - Closures

    public func dataTask(with request: URLRequest, completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> URLSessionDataTask {
        // TODO: refactor and remove retain cycles
        var task: URLSessionDataTask?
        let onReceive: (Data?, URLResponse?, Error?) -> Void = { (data, response, error) in
            if let task {
                if let data {
                    self.logger.logDataTask(task, didReceive: data)
                }
                self.logger.logTask(task, didCompleteWithError: error)
            }
        }
        task = session.dataTask(with: request) {data, response, error in
            onReceive(data, response, error)
            completionHandler(data, response, error)
        }
        return task!
    }

    public func dataTask(with url: URL, completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> URLSessionDataTask {
        fatalError("Not implemented")
    }

    public func uploadTask(with request: URLRequest, fromFile fileURL: URL, completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> URLSessionUploadTask {
        fatalError("Not implemented")
    }

    public func uploadTask(with request: URLRequest, from bodyData: Data?, completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> URLSessionUploadTask {
        fatalError("Not implemented")
    }

    public func uploadTask(withResumeData resumeData: Data, completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> URLSessionUploadTask {
        fatalError("Not implemented")
    }

    public func downloadTask(with request: URLRequest, completionHandler: @escaping @Sendable (URL?, URLResponse?, (any Error)?) -> Void) -> URLSessionDownloadTask {
        fatalError("Not implemented")
    }

    public func downloadTask(with url: URL, completionHandler: @escaping @Sendable (URL?, URLResponse?, (any Error)?) -> Void) -> URLSessionDownloadTask {
        fatalError("Not implemented")
    }

    public func downloadTask(withResumeData resumeData: Data, completionHandler: @escaping @Sendable (URL?, URLResponse?, (any Error)?) -> Void) -> URLSessionDownloadTask {
        fatalError("Not implemented")
    }

    // MARK: - Combine

    // TODO: add support for logging requests from Combine
    public func dataTaskPublisher(for url: URL) -> URLSession.DataTaskPublisher {
        session.dataTaskPublisher(for: url)
    }

    public func dataTaskPublisher(for request: URLRequest) -> URLSession.DataTaskPublisher {
        session.dataTaskPublisher(for: request)
    }

    // MARK: - Swift Concurrency

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await data(for: request, delegate: nil)
    }

    public func data(from url: URL) async throws -> (Data, URLResponse) {
        fatalError("Not implemented")
    }

    public func upload(for request: URLRequest, fromFile fileURL: URL) async throws -> (Data, URLResponse) {
        fatalError("Not implemented")
    }

    public func upload(for request: URLRequest, from bodyData: Data) async throws -> (Data, URLResponse) {
        fatalError("Not implemented")
    }

    // TODO: Make it a standalone feature.
    public func data(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse) {
        // TODO: is this an isssue because with use the same delegate when creating session?
        // TODO: Make createdTask public here? probably not
        let delegate = URLSessionProxyDelegate(logger: logger, delegate: delegate)
        do {
            let (data, response) = try await session.data(for: request, delegate: delegate)
            // TODO: use mutex here?
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

    public func data(from url: URL, delegate: (any URLSessionTaskDelegate)? = nil) async throws -> (Data, URLResponse) {
        try await data(for: URLRequest(url: url), delegate: delegate)
    }

    public func upload(for request: URLRequest, fromFile fileURL: URL, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse) {
        fatalError("Not implemented")
    }

    public func upload(for request: URLRequest, from bodyData: Data, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse) {
        fatalError("Not implemented")
    }
}
