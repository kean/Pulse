// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation

/// A thin wrapper on top of `URLSession` that simplifies logging of network
/// requests and enables other Pulse features.
public final class URLSessionProxy: URLSessionProtocol, @unchecked Sendable {
    /// A configuration object that defines session behavior.
    public struct Options: Sendable {
        /// If enabled, registers ``MockingURLProtocol``.
        public var isMockingEnabled = true

        /// Creates default options.
        public init() {}
    }

    /// The underlying `URLSession`.
    public let session: Foundation.URLSession
    var logger: NetworkLogger { _logger ?? .shared }
    private let _logger: NetworkLogger?
    private let options: Options

    /// - parameter logger: A custom logger to use instead of ``NetworkLogger/shared``.
    public convenience init(
        configuration: URLSessionConfiguration,
        logger: NetworkLogger? = nil,
        options: Options = .init()
    ) {
        self.init(configuration: configuration, delegate: nil, delegateQueue: nil, options: options)
    }

    /// - parameter logger: A custom logger to use instead of ``NetworkLogger/shared``.
    public init(
        configuration: URLSessionConfiguration,
        delegate: (any URLSessionDelegate)?,
        delegateQueue: OperationQueue? = nil,
        logger: NetworkLogger? = nil,
        options: Options = .init()
    ) {
        if options.isMockingEnabled {
            configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        }
        self.session = Foundation.URLSession(
            configuration: configuration,
            delegate: URLSessionProxyDelegate(logger: logger, delegate: delegate),
            delegateQueue: delegateQueue
        )
        self.options = options
        self._logger = logger
    }

    // MARK: - URLSessionProtocol (Core)

    // These APIs work out of the box thanks to `URLSessionProxyDelegate`.

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

    // MARK: - URLSessionProtocol (Closures)

    public func dataTask(with request: URLRequest, completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> URLSessionDataTask {
        let box = Mutex<URLSessionDataTask?>(nil)
        let task = session.dataTask(with: request) { [logger] data, response, error in
            if let task = box.value {
                if let data {
                    logger.logDataTask(task, didReceive: data)
                }
                logger.logTask(task, didCompleteWithError: error)
            }
            completionHandler(data, response, error)
        }
        box.value = task
        return task
    }

    public func dataTask(with url: URL, completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> URLSessionDataTask {
        dataTask(with: URLRequest(url: url), completionHandler: completionHandler)
    }

    public func uploadTask(with request: URLRequest, fromFile fileURL: URL, completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> URLSessionUploadTask {
        let box = Mutex<URLSessionUploadTask?>(nil)
        let task = session.uploadTask(with: request, fromFile: fileURL) { [logger] data, response, error in
            if let task = box.value {
                if let data {
                    logger.logDataTask(task, didReceive: data)
                }
                logger.logTask(task, didCompleteWithError: error)
            }
            completionHandler(data, response, error)
        }
        box.value = task
        return task
    }

    public func uploadTask(with request: URLRequest, from bodyData: Data?, completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> URLSessionUploadTask {
        let box = Mutex<URLSessionUploadTask?>(nil)
        let task = session.uploadTask(with: request, from: bodyData) { [logger] data, response, error in
            if let task = box.value {
                if let data {
                    logger.logDataTask(task, didReceive: data)
                }
                logger.logTask(task, didCompleteWithError: error)
            }
            completionHandler(data, response, error)
        }
        box.value = task
        return task
    }

    @available(iOS 17, tvOS 17, macOS 14, watchOS 9, *)
    public func uploadTask(withResumeData resumeData: Data, completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> URLSessionUploadTask {
        let box = Mutex<URLSessionUploadTask?>(nil)
        let task = session.uploadTask(withResumeData: resumeData) { [logger] data, response, error in
            if let task = box.value {
                if let data {
                    logger.logDataTask(task, didReceive: data)
                }
                logger.logTask(task, didCompleteWithError: error)
            }
            completionHandler(data, response, error)
        }
        box.value = task
        return task
    }

    public func downloadTask(with request: URLRequest, completionHandler: @escaping @Sendable (URL?, URLResponse?, (any Error)?) -> Void) -> URLSessionDownloadTask {
        let box = Mutex<URLSessionDownloadTask?>(nil)
        let task = session.downloadTask(with: request) { [logger] url, response, error in
            if let task = box.value {
                logger.logTask(task, didCompleteWithError: error)
            }
            completionHandler(url, response, error)
        }
        box.value = task
        return task
    }

    public func downloadTask(with url: URL, completionHandler: @escaping @Sendable (URL?, URLResponse?, (any Error)?) -> Void) -> URLSessionDownloadTask {
        downloadTask(with: URLRequest(url: url), completionHandler: completionHandler)
    }

    public func downloadTask(withResumeData resumeData: Data, completionHandler: @escaping @Sendable (URL?, URLResponse?, (any Error)?) -> Void) -> URLSessionDownloadTask {
        let box = Mutex<URLSessionDownloadTask?>(nil)
        let task = session.downloadTask(withResumeData: resumeData) { [logger] url, response, error in
            if let task = box.value {
                logger.logTask(task, didCompleteWithError: error)
            }
            completionHandler(url, response, error)
        }
        box.value = task
        return task
    }

    // MARK: - URLSessionProtocol (Combine)

    public func dataTaskPublisher(for url: URL) -> URLSession.DataTaskPublisher {
        session.dataTaskPublisher(for: url)
    }

    public func dataTaskPublisher(for request: URLRequest) -> URLSession.DataTaskPublisher {
        session.dataTaskPublisher(for: request)
    }

    // MARK: - URLSessionProtocol (Swift Concurrency)

    public func data(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse) {
        let delegate = URLSessionProxyDelegate(logger: logger, delegate: delegate)
        do {
            let (data, response) = try await session.data(for: request, delegate: delegate)
            if let task = delegate.createdTask.value as? URLSessionDataTask {
                logger.logDataTask(task, didReceive: data)
                logger.logTask(task, didCompleteWithError: nil)
            }
            return (data, response)
        } catch {
            if let task = delegate.createdTask.value {
                logger.logTask(task, didCompleteWithError: error)
            }
            throw error
        }
    }

    public func data(from url: URL, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse) {
        try await data(for: URLRequest(url: url), delegate: delegate)
    }

    public func upload(for request: URLRequest, fromFile fileURL: URL, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse) {
        let delegate = URLSessionProxyDelegate(logger: logger, delegate: delegate)
        do {
            let (data, response) = try await session.upload(for: request, fromFile: fileURL)
            if let task = delegate.createdTask.value as? URLSessionUploadTask {
                logger.logDataTask(task, didReceive: data)
                logger.logTask(task, didCompleteWithError: nil)
            }
            return (data, response)
        } catch {
            if let task = delegate.createdTask.value {
                logger.logTask(task, didCompleteWithError: error)
            }
            throw error
        }
    }

    public func upload(for request: URLRequest, from bodyData: Data, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse) {
        let delegate = URLSessionProxyDelegate(logger: logger, delegate: delegate)
        do {
            let (data, response) = try await session.upload(for: request, from: bodyData)
            if let task = delegate.createdTask.value as? URLSessionUploadTask {
                logger.logDataTask(task, didReceive: data)
                logger.logTask(task, didCompleteWithError: nil)
            }
            return (data, response)
        } catch {
            if let task = delegate.createdTask.value {
                logger.logTask(task, didCompleteWithError: error)
            }
            throw error
        }
    }

    public func download(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (URL, URLResponse) {
        let delegate = URLSessionProxyDelegate(logger: logger, delegate: delegate)
        do {
            let (url, response) = try await session.download(for: request, delegate: delegate)
            if let task = delegate.createdTask.value as? URLSessionDownloadTask {
                logger.logTask(task, didCompleteWithError: nil)
            }
            return (url, response)
        } catch {
            if let task = delegate.createdTask.value {
                logger.logTask(task, didCompleteWithError: error)
            }
            throw error
        }
    }

    public func download(from url: URL, delegate: (any URLSessionTaskDelegate)?) async throws -> (URL, URLResponse) {
        try await download(for: URLRequest(url: url), delegate: delegate)
    }

    public func download(resumeFrom resumeData: Data, delegate: (any URLSessionTaskDelegate)?) async throws -> (URL, URLResponse) {
        let delegate = URLSessionProxyDelegate(logger: logger, delegate: delegate)
        do {
            let (url, response) = try await session.download(resumeFrom: resumeData, delegate: delegate)
            if let task = delegate.createdTask.value as? URLSessionDownloadTask {
                logger.logTask(task, didCompleteWithError: nil)
            }
            return (url, response)
        } catch {
            if let task = delegate.createdTask.value {
                logger.logTask(task, didCompleteWithError: error)
            }
            throw error
        }
    }

    public func bytes(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (URLSession.AsyncBytes, URLResponse) {
        try await session.bytes(for: request, delegate: delegate)
    }

    public func bytes(from url: URL, delegate: (any URLSessionTaskDelegate)?) async throws -> (URLSession.AsyncBytes, URLResponse) {
        try await session.bytes(from: url, delegate: delegate)
    }
}
