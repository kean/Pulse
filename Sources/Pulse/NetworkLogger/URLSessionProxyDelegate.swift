// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation

/// Automates URLSession request tracking.
///
/// - important: On iOS 16.0, tvOS 16.0, macOS 13.0, watchOS 9.0, it automatically
/// tracks new task creation using the `urlSession(_:didCreateTask:)` delegate
/// method which allows the logger to start tracking network requests right
/// after their creation. On earlier versions, you can (optionally) call
/// ``NetworkLogger/logTaskCreated(_:)`` manually.
public final class URLSessionProxyDelegate: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate, URLSessionDownloadDelegate {
    private let actualDelegate: URLSessionDelegate?
    private let taskDelegate: URLSessionTaskDelegate?
    private let interceptedSelectors: Set<Selector>
    private let logger: NetworkLogger

    /// - parameter logger: By default, creates a logger with `LoggerStore.shared`.
    /// - parameter delegate: The "actual" session delegate, strongly retained.
    public init(logger: NetworkLogger = .init(), delegate: URLSessionDelegate? = nil) {
        self.actualDelegate = delegate
        self.taskDelegate = delegate as? URLSessionTaskDelegate
        self.logger = logger
        var interceptedSelectors: Set = [
            #selector(URLSessionDataDelegate.urlSession(_:dataTask:didReceive:)),
            #selector(URLSessionTaskDelegate.urlSession(_:task:didCompleteWithError:)),
            #selector(URLSessionTaskDelegate.urlSession(_:task:didFinishCollecting:)),
            #selector(URLSessionTaskDelegate.urlSession(_:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:)),
            #selector(URLSessionDownloadDelegate.urlSession(_:downloadTask:didFinishDownloadingTo:)),
            #selector(URLSessionDownloadDelegate.urlSession(_:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:))
        ]
        if #available(iOS 16.0, tvOS 16.0, macOS 13.0, watchOS 9.0, *) {
            interceptedSelectors.insert(#selector(URLSessionTaskDelegate.urlSession(_:didCreateTask:)))
        }
        self.interceptedSelectors = interceptedSelectors
    }

    // MARK: URLSessionTaskDelegate

    var createdTask: URLSessionTask?

    public func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        createdTask = task
        logger.logTaskCreated(task)
        if #available(iOS 16.0, tvOS 16.0, macOS 13.0, watchOS 9.0, *) {
            taskDelegate?.urlSession?(session, didCreateTask: task)
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        logger.logTask(task, didCompleteWithError: error)
        taskDelegate?.urlSession?(session, task: task, didCompleteWithError: error)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        logger.logTask(task, didFinishCollecting: metrics)
        taskDelegate?.urlSession?(session, task: task, didFinishCollecting: metrics)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        if task is URLSessionUploadTask {
            logger.logTask(task, didUpdateProgress: (completed: totalBytesSent, total: totalBytesExpectedToSend))
        }
        (actualDelegate as? URLSessionTaskDelegate)?.urlSession?(session, task: task, didSendBodyData: bytesSent, totalBytesSent: totalBytesSent, totalBytesExpectedToSend: totalBytesExpectedToSend)
    }

    // MARK: URLSessionDataDelegate

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        logger.logDataTask(dataTask, didReceive: data)
        (actualDelegate as? URLSessionDataDelegate)?.urlSession?(session, dataTask: dataTask, didReceive: data)
    }

    // MARK: URLSessionDownloadDelegate

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        (actualDelegate as? URLSessionDownloadDelegate)?.urlSession(session, downloadTask: downloadTask, didFinishDownloadingTo: location)
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        logger.logTask(downloadTask, didUpdateProgress: (completed: totalBytesWritten, total: totalBytesExpectedToWrite))
        (actualDelegate as? URLSessionDownloadDelegate)?.urlSession?(session, downloadTask: downloadTask, didWriteData: bytesWritten, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
    }

    // MARK: Proxy

    public override func responds(to aSelector: Selector!) -> Bool {
        if interceptedSelectors.contains(aSelector) {
            return true
        }
        return (actualDelegate?.responds(to: aSelector) ?? false) || super.responds(to: aSelector)
    }

    public override func forwardingTarget(for selector: Selector!) -> Any? {
        interceptedSelectors.contains(selector) ? nil : actualDelegate
    }
}

extension URLSession {
    // TODO: allow configuring shared logger
    public var proxy: NetworkCapturingProxy {
        NetworkCapturingProxy(session: self, logger: .shared)
    }

    // TODO: add other methods + completion-based APIs
    public struct NetworkCapturingProxy {
        let session: URLSession
        let logger: NetworkLogger

        @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
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

        @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
        public func data(from url: URL, delegate: (any URLSessionTaskDelegate)? = nil) async throws -> (Data, URLResponse) {
            try await data(for: URLRequest(url: url), delegate: delegate)
        }
    }
}

public protocol URLSessionProtocol {
    /// Convenience method to load data using a URLRequest, creates and resumes a URLSessionDataTask internally.
    ///
    /// - Parameter request: The URLRequest for which to load data.
    /// - Parameter delegate: Task-specific delegate.
    /// - Returns: Data and response.
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func data(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse)

    /// Convenience method to load data using a URL, creates and resumes a URLSessionDataTask internally.
    ///
    /// - Parameter url: The URL for which to load data.
    /// - Parameter delegate: Task-specific delegate.
    /// - Returns: Data and response.
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func data(from url: URL, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

//public final class URLSessionProxy {
//    
//}

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
