// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Foundation
import Logging

public final class URLSessionProxyDelegate: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate {
    private weak var actualDelegate: URLSessionTaskDelegate?
    private let interceptedSelectors: Set<Selector>
    private let logger: NetworkLogger

    public init(logger: NetworkLogger, delegate: URLSessionTaskDelegate) {
        self.actualDelegate = delegate
        self.interceptedSelectors = [
            #selector(urlSession(_:dataTask:didReceive:)),
            #selector(urlSession(_:task:didCompleteWithError:)),
            #selector(urlSession(_:dataTask:didReceive:completionHandler:)),
            #selector(urlSession(_:task:didFinishCollecting:))
        ]
        self.logger = logger
    }

    // MARK: URLSessionTaskDelegate

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        logger.logTask(task, didCompleteWithError: error)
        actualDelegate?.urlSession?(session, task: task, didCompleteWithError: error)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        logger.logTask(task, didFinishCollecting: metrics)
        actualDelegate?.urlSession?(session, task: task, didFinishCollecting: metrics)
    }

    // MARK: URLSessionDataDelegate

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        logger.logDataTask(dataTask, didReceive: response)
        (actualDelegate as? URLSessionDataDelegate)?.urlSession?(session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        logger.logDataTask(dataTask, didReceive: data)
        (actualDelegate as? URLSessionDataDelegate)?.urlSession?(session, dataTask: dataTask, didReceive: data)
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
