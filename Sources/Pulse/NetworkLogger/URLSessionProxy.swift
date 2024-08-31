// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation

@MainActor
public final class URLSessionProxy {
    static var proxy: URLSessionProxy?

    let logger: NetworkLogger

    init(logger: NetworkLogger) {
        self.logger = logger
    }

    /// Enables automatic `URLSession` logging.
    ///
    /// - parameter logger: The network logger to be used for recording the requests.
    public static func enable(with logger: NetworkLogger = .init()) {
        guard URLSessionProxy.proxy == nil else {
            NSLog("Error: Pulse.URLSessionProxy already enabled")
            return
        }
        guard sharedNetworkLogger == nil else {
            NSLog("Error: Pulse network request logging is already enabled")
            return
        }
        let proxy = URLSessionProxy(logger: logger)
        proxy.enable()
        URLSessionProxy.proxy = proxy
    }

    func enable() {
        swizzleURLSessionTaskResume()
        // "__NSCFURLLocalSessionConnection"
        if let sessionClass = NSClassFromString(["__", "NS", "CFURL", "Local", "Session", "Connection"].joined()) {
            swizzleDataTaskDidReceiveData(baseClass: sessionClass)
            swizzleDataDataDidCompleteWithError(baseClass: sessionClass)
        } else {
            NSLog("Pulse.URLSessionProxy failed to initialize. Please report at https://github.com/kean/Pulse/issues.")
        }
    }

    // - `resume` (optional)
    private func swizzleURLSessionTaskResume() {
        var methods = [Method]()
        if let method = class_getInstanceMethod(URLSessionTask.self, #selector(URLSessionTask.resume)) {
            methods.append(method)
        }
        // "__NSCFURLSessionTask"
        if let sessionTaskClass = NSClassFromString(["__", "NS", "CFURL", "Session", "Task"].joined()),
           let method = class_getInstanceMethod(sessionTaskClass, NSSelectorFromString("resume")) {
            methods.append(method)
        }
        methods.forEach {
            let method = $0
            var originalImplementation: IMP?
            let block: @convention(block) (URLSessionTask) -> Void = { [weak self] task in
                self?.logger.logTaskCreated(task)
                guard task.currentRequest != nil else { return }
                let key = String(method.hashValue)
                objc_setAssociatedObject(task, key, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                let castedIMP = unsafeBitCast(originalImplementation, to: (@convention(c) (Any) -> Void).self)
                castedIMP(task)
                objc_setAssociatedObject(task, key, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
            let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
            originalImplementation = method_setImplementation(method, swizzledIMP)
        }
    }

    // - `urlSession(_:task:didCompleteWithError:)`
    func swizzleDataDataDidCompleteWithError(baseClass: AnyClass) {
        // "_didFinishWithError:"
        let selector = NSSelectorFromString(["_", "didFinish", "With", "Error", ":"].joined())
        guard let method = class_getInstanceMethod(baseClass, selector),
            baseClass.instancesRespond(to: selector) else {
            return
        }
        typealias MethodSignature = @convention(c) (AnyObject, Selector, AnyObject?) -> Void
        let originalImp: IMP = method_getImplementation(method)
        let closure: @convention(block) (AnyObject, AnyObject?) -> Void = { [weak self] object, error in
            let original: MethodSignature = unsafeBitCast(originalImp, to: MethodSignature.self)
            original(object, selector, error)

            if let task = object.value(forKey: "task") as? URLSessionTask {
                // "_incompleteTaskMetrics"
                if let metrics = task.value(forKey: ["_", "incomplete", "Task", "Metrics"].joined()) as? URLSessionTaskMetrics {
                    self?.logger.logTask(task, didFinishCollecting: metrics)
                }
                let error = error as? Error
                self?.logger.logTask(task, didCompleteWithError: error)
            }
        }
        method_setImplementation(method, imp_implementationWithBlock(closure))
    }

    // - `urlSession(_:dataTask:didReceive:)`
    func swizzleDataTaskDidReceiveData(baseClass: AnyClass) {
        // "_didReceiveData"
        let selector = NSSelectorFromString(["_", "did", "Receive", "Data", ":"].joined())
        guard let method = class_getInstanceMethod(baseClass, selector),
            baseClass.instancesRespond(to: selector) else {
            return
        }

        typealias MethodSignature =  @convention(c) (AnyObject, Selector, AnyObject) -> Void
        let originalImp: IMP = method_getImplementation(method)
        let closure: @convention(block) (AnyObject, AnyObject) -> Void = { [weak self] (object, data) in
            let original: MethodSignature = unsafeBitCast(originalImp, to: MethodSignature.self)
            original(object, selector, data)

            if let task = object.value(forKey: "task") as? URLSessionDataTask {
                let data = (data as? Data) ?? Data()
                self?.logger.logDataTask(task, didReceive: data)
            }
        }
        method_setImplementation(method, imp_implementationWithBlock(closure))
    }
}

// MARK: - Experimental (Deprecated)

@available(*, deprecated, message: "Experimental.URLSessionProxy is replaced with a reworked URLSessionProxy")
public enum Experimental {}

@available(*, deprecated, message: "Experimental.URLSessionProxy is replaced with a reworked URLSessionProxy")
public extension Experimental {
    @MainActor
    final class URLSessionProxy {
        public static let shared = URLSessionProxy()
        public var logger: NetworkLogger = .init()
        public var configuration: URLSessionConfiguration = .default
        public var ignoredHosts = Set<String>()

        public var isEnabled: Bool = false {
            didSet {
                if isEnabled {
                    Pulse.URLSessionProxy.enable(with: logger)
                } else {
                    NSLog("Pulse.URLSessionProxy can't be disabled at runtime")
                }
            }
        }
    }
}
