// The MIT License (MIT)
//
// Copyright (c) 2020-2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import PulseUI
import Pulse

// If you want to avoid using swizzling and proxies, just implement the following
// URLSession delegate methods.
final class URLSessionManualIntegration {
    private let logger: NetworkLogger
    private let delegate: SessionDelegate
    private let session: URLSession

    init() {
        logger = NetworkLogger()
        delegate = SessionDelegate(logger: logger)
        session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
    }

    /// Loads data with the given request.
    func loadData(with request: URLRequest,
                  didReceiveData: @escaping (Data, URLResponse) -> Void,
                  completion: @escaping (Error?) -> Void) -> URLSessionDataTask {
        delegate.loadData(with: request, session: session, didReceiveData: didReceiveData, completion: completion)
    }
}

private final class SessionDelegate: NSObject, URLSessionDataDelegate {
    private let logger: NetworkLogger
    private var handlers = [URLSessionTask: _Handler]()

    init(logger: NetworkLogger) {
        self.logger = logger
    }

    /// Loads data with the given request.
    func loadData(with request: URLRequest,
                  session: URLSession,
                  didReceiveData: @escaping (Data, URLResponse) -> Void,
                  completion: @escaping (Error?) -> Void) -> URLSessionDataTask {
        let task = session.dataTask(with: request)
        let handler = _Handler(didReceiveData: didReceiveData, completion: completion)
        session.delegateQueue.addOperation { // `URLSession` is configured to use this same queue
            self.handlers[task] = handler
        }
        task.resume()
        logger.logTaskCreated(task)
        return task
    }

    // MARK: URLSessionDelegate

    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        logger.logDataTask(dataTask, didReceive: response)
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        assert(task is URLSessionDataTask)
        logger.logTask(task, didCompleteWithError: error)
        guard let handler = handlers[task] else {
            return
        }
        handlers[task] = nil
        handler.completion(error)
    }

    // MARK: URLSessionDataDelegate

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        logger.logDataTask(dataTask, didReceive: data)

        guard let handler = handlers[dataTask], let response = dataTask.response else {
            return
        }
        // Don't store data anywhere, just send it to the pipeline.
        handler.didReceiveData(data, response)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        logger.logTask(task, didFinishCollecting: metrics)
    }

    // MARK: Internal

    private final class _Handler {
        let didReceiveData: (Data, URLResponse) -> Void
        let completion: (Error?) -> Void

        init(didReceiveData: @escaping (Data, URLResponse) -> Void, completion: @escaping (Error?) -> Void) {
            self.didReceiveData = didReceiveData
            self.completion = completion
        }
    }
}
