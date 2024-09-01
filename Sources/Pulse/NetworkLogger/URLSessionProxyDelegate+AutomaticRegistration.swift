// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation

extension URLSessionProxyDelegate {
    /// Enables automatic logging and remote debugging of network requests using
    /// `URLSessionProxyDelegate`.
    ///
    /// - note: This method works by swizzling `URLSession` init and adding
    /// `URLSessionProxyDelegate` to the delegate chain and adding
    /// `RemoteLoggerURLProtocol` to the list of session protocol classes.
    ///
    /// - warning: This logging method works only with delegate-based `URLSession`
    /// instances. If it doesn't work for you, consider using ``URLSessionProxy``
    /// for automatic logging or manually logging the requests using ``NetworkLogger``.
    ///
    /// - parameter logger: The network logger to be used for recording the requests. By default, uses shared logger.
    public static func enableAutomaticRegistration(logger: NetworkLogger? = nil) {
        guard Thread.isMainThread else {
            return DispatchQueue.main.async { _enableAutomaticRegistration(logger: logger) }
        }
        MainActor.assumeIsolated {
            _enableAutomaticRegistration(logger: logger)
        }
    }

    @MainActor
    static func _enableAutomaticRegistration(logger: NetworkLogger?) {
        guard !isAutomaticNetworkLoggingEnabled else { return }

        sharedNetworkLogger = logger
        if let lhs = class_getClassMethod(URLSession.self, #selector(URLSession.init(configuration:delegate:delegateQueue:))),
           let rhs = class_getClassMethod(URLSession.self, #selector(URLSession.pulse_init(configuration:delegate:delegateQueue:))) {
            method_exchangeImplementations(lhs, rhs)
        }
    }
}

/// Returns `true` if automatic logging was already enabled using one of the
/// existing mechanisms provided by Pulse.
@MainActor
var isAutomaticNetworkLoggingEnabled: Bool {
    guard sharedNetworkLogger == nil else {
        NSLog("Error: Pulse network request logging is already enabled")
        return true
    }
    return false
}

func isConfiguringSessionSafe(delegate: URLSessionDelegate?) -> Bool {
    if String(describing: delegate).contains("GTMSessionFetcher") {
        return false
    }
    return true
}

private var sharedNetworkLogger: NetworkLogger? {
    get { _sharedLogger.value }
    set { _sharedLogger.value = newValue }
}
private let _sharedLogger = Mutex<NetworkLogger?>(nil)

private extension URLSession {
    @objc class func pulse_init(configuration: URLSessionConfiguration, delegate: URLSessionDelegate?, delegateQueue: OperationQueue?) -> URLSession {
        guard isConfiguringSessionSafe(delegate: delegate) else {
            return self.pulse_init(configuration: configuration, delegate: delegate, delegateQueue: delegateQueue)
        }
        configuration.protocolClasses = [RemoteLoggerURLProtocol.self] + (configuration.protocolClasses ?? [])
        let delegate = URLSessionProxyDelegate(logger: sharedNetworkLogger, delegate: delegate)
        return self.pulse_init(configuration: configuration, delegate: delegate, delegateQueue: delegateQueue)
    }
}

// MARK: - Experimental (Deprecated)

@available(*, deprecated, message: "Experimental.URLSessionProxy is replaced with NetworkLogger.enableProxy() from the PulseProxy target")
public enum Experimental {}

@available(*, deprecated, message: "Experimental.URLSessionProxy is replaced with NetworkLogger.enableProxy() from the PulseProxy target")
public extension Experimental {
    @MainActor
    final class URLSessionProxy {
        public static let shared = URLSessionProxy()
        public var logger: NetworkLogger = .init()
        public var configuration: URLSessionConfiguration = .default
        public var ignoredHosts = Set<String>()

        public var isEnabled: Bool = false {
            didSet {
                NSLog("Pulse.URLSessionProxu can't be disabled at runtime")
            }
        }
    }
}
