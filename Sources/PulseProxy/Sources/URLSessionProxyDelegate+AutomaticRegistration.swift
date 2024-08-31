// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse

public extension URLSessionProxyDelegate {
    /// Enables automatic registration of `URLSessionProxyDelegate`. After calling this method, every time
    /// you initialize a `URLSession` using `init(configuration:delegate:delegateQueue:))` method, the
    /// delegate will automatically get replaced with a `URLSessionProxyDelegate` that logs all the
    /// needed events and forwards the methods to your original delegate.
    public static func enableAutomaticRegistration(logger: NetworkLogger = .init()) {
        sharedLogger = logger
        if let lhs = class_getClassMethod(URLSession.self, #selector(URLSession.init(configuration:delegate:delegateQueue:))),
           let rhs = class_getClassMethod(URLSession.self, #selector(URLSession.pulse_init(configuration:delegate:delegateQueue:))) {
            method_exchangeImplementations(lhs, rhs)
        }
    }
}

private var sharedLogger: NetworkLogger? {
    get { _sharedLogger.value }
    set { _sharedLogger.value = newValue }
}
private let _sharedLogger = Mutex<NetworkLogger?>(nil)

private extension URLSession {
    @objc class func pulse_init(configuration: URLSessionConfiguration, delegate: URLSessionDelegate?, delegateQueue: OperationQueue?) -> URLSession {
        guard !String(describing: delegate).contains("GTMSessionFetcher") else {
            return self.pulse_init(configuration: configuration, delegate: delegate, delegateQueue: delegateQueue)
        }
        configuration.protocolClasses = [RemoteLoggerURLProtocol.self] + (configuration.protocolClasses ?? [])
        guard let sharedLogger else {
            assertionFailure("Shared logger is missing")
            return self.pulse_init(configuration: configuration, delegate: delegate, delegateQueue: delegateQueue)
        }
        let delegate = URLSessionProxyDelegate(logger: sharedLogger, delegate: delegate)
        return self.pulse_init(configuration: configuration, delegate: delegate, delegateQueue: delegateQueue)
    }
}
