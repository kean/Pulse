// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation

public enum Experimental {
}

public extension Experimental {
    /// WARNING: Experimental.
    final class URLSessionProxy {
        public static let shared = URLSessionProxy()

        private init() {
            session = URLSession(configuration: .default, delegate: URLSessionProxyDelegate(logger: logger, delegate: CustomProtocolSessionDelegate.shared), delegateQueue: CustomProtocolSessionDelegate.shared.queue)
        }

        /// Network logger to be used for storing the requests. By default,
        /// uses the logger with the `.default` store.
        public var logger: NetworkLogger = .init() {
            didSet { resetSession() }
        }

        /// By default, `.default`.
        public var configuration: URLSessionConfiguration = .default {
            didSet { resetSession() }
        }

        /// By default, empty.
        public var ignoredHosts = Set<String>()

        public var isEnabled: Bool = false {
            didSet {
                if isEnabled {
                    URLProtocol.registerClass(CustomHTTPProtocol.self)
                } else {
                    URLProtocol.unregisterClass(CustomHTTPProtocol.self)
                }
            }
        }

        // MARK: URLSession

        fileprivate var session: URLSession

        private func resetSession() {
            session.invalidateAndCancel()
            configuration.protocolClasses?.insert(CustomHTTPProtocol.self, at: 0)
            session = URLSession(configuration: configuration, delegate: URLSessionProxyDelegate(logger: logger, delegate: CustomProtocolSessionDelegate.shared), delegateQueue: CustomProtocolSessionDelegate.shared.queue)
        }
    }
}

private final class CustomHTTPProtocol: URLProtocol {
    struct Constants {
        static let RequestHandledKey = "URLProtocolRequestHandled"
    }

    var sessionTask: URLSessionDataTask?

    override init(request: URLRequest, cachedResponse: CachedURLResponse?, client: URLProtocolClient?) {
        super.init(request: request, cachedResponse: cachedResponse, client: client)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard CustomHTTPProtocol.shouldHandleRequest(request) else {
            return false
        }
        if CustomHTTPProtocol.property(forKey: Constants.RequestHandledKey, in: request) != nil {
            return false
        }
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let newRequest = ((request as NSURLRequest).mutableCopy() as? NSMutableURLRequest) else {
            return assertionFailure()
        }
        CustomHTTPProtocol.setProperty(true, forKey: Constants.RequestHandledKey, in: newRequest)
        let dataTask = Experimental.URLSessionProxy.shared.session.dataTask(with: newRequest as URLRequest)
        let handler = RequestHandler(proto: self)
        CustomProtocolSessionDelegate.shared.register(handler, for: dataTask)
        dataTask.resume()

        DispatchQueue.main.async {
            self.sessionTask = dataTask
        }
    }

    override func stopLoading() {
        sessionTask?.cancel()
    }

    private func body(from request: URLRequest) -> Data? {
        /// The receiver will have either an HTTP body or an HTTP body stream only one may be set for a request.
        /// A HTTP body stream is preserved when copying an NSURLRequest object,
        /// but is lost when a request is archived using the NSCoding protocol.
        return request.httpBody // ?? request.httpBodyStream?.readfully()
    }

    /// Inspects the request to see if the host has not been blacklisted and can be handled by this URL protocol.
    /// - Parameter request: The request being processed.
    private class func shouldHandleRequest(_ request: URLRequest) -> Bool {
        guard let host = request.url?.host else {
            return true
        }
        return !Experimental.URLSessionProxy.shared.ignoredHosts.contains(where: host.hasSuffix)
    }

    deinit {
        sessionTask = nil
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        client?.urlProtocol(self, didLoad: data)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        let policy = URLCache.StoragePolicy(rawValue: request.cachePolicy.rawValue) ?? .notAllowed
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: policy)
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        client?.urlProtocol(self, wasRedirectedTo: request, redirectResponse: response)
        completionHandler(request)
    }
}

private final class CustomProtocolSessionDelegate: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate {
    static let shared = CustomProtocolSessionDelegate()

    let queue = OperationQueue()
    var handlers: [URLSessionTask: RequestHandler] = [:]

    override init() {
        queue.maxConcurrentOperationCount = 1
    }

    func register(_ handler: RequestHandler, for task: URLSessionTask) {
        queue.addOperation { // `URLSession` is configured to use this same queue
            self.handlers[task] = handler
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        handlers[dataTask]?.proto.urlSession(session, dataTask: dataTask, didReceive: data)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        handlers[dataTask]?.proto.urlSession(session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        handlers[task]?.proto.urlSession(session, task: task, didCompleteWithError: error)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        handlers[task]?.proto.urlSession(session, task: task, willPerformHTTPRedirection: response, newRequest: request, completionHandler: completionHandler)
    }
}

private final class RequestHandler {
    let proto: CustomHTTPProtocol

    init(proto: CustomHTTPProtocol) {
        self.proto = proto
    }
}
