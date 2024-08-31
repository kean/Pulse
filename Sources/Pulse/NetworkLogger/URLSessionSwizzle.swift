// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation

final class NetworkLoggerURLSessionSwizzlerDelegate: URLSessionSwizzlerDelegate {

    private let logger: NetworkLogger

    init(logger: NetworkLogger = .init()) {
        self.logger = logger
    }

    func swizzlerSessionDidCallResume(task: URLSessionTask) {
        logger.logTaskCreated(task)
    }

    func swizzlerSessionDidComplete(task: URLSessionTask, error: (any Error)?) {
        logger.logTask(task, didCompleteWithError: error)
    }

    func swizzlerSessionDidFinishCollectingMetrics(task: URLSessionTask, metrics: URLSessionTaskMetrics) {
        logger.logTask(task, didFinishCollecting: metrics)
    }

    func swizzlerSessionDidReceiveData(dataTask: URLSessionDataTask, data: Data) {
        logger.logDataTask(dataTask, didReceive: data)
    }
}


protocol URLSessionSwizzlerDelegate: AnyObject {
    func swizzlerSessionDidCallResume(task: URLSessionTask)
    func swizzlerSessionDidComplete(task: URLSessionTask, error: (any Error)?)
    func swizzlerSessionDidFinishCollectingMetrics(task: URLSessionTask, metrics: URLSessionTaskMetrics)
    func swizzlerSessionDidReceiveData(dataTask: URLSessionDataTask, data: Data)
}

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
            NSLog("Pulse.URLSessionProxy already enabled")
            return
        }
        let proxy = URLSessionProxy(logger: logger)
        proxy.enable()
        URLSessionProxy.proxy = proxy
    }

    func enable() {
        injectIntoNSURLSessionTaskResume()
        if let sessionClass = NSClassFromString("__NSCFURLLocalSessionConnection") {
            injectIntoURLSessionDelegate(anyClass: sessionClass)
        }
    }

    private func injectIntoURLSessionDelegate(anyClass: AnyClass) {
        swizzleDataTaskDidReceiveData(baseClass: anyClass)
        swizzleDataDataDidCompleteWithError(baseClass: anyClass)
    }

    private func injectIntoNSURLSessionTaskResume() {
        var methodsToSwizzle = [Method]()

        if let method = class_getInstanceMethod(URLSessionTask.self, #selector(URLSessionTask.resume)) {
            methodsToSwizzle.append(method)
        }

        if let cfURLSession = NSClassFromString("__NSCFURLSessionTask"),
           let method = class_getInstanceMethod(cfURLSession, NSSelectorFromString("resume")) {
            methodsToSwizzle.append(method)
        }

        methodsToSwizzle.forEach {
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
}

extension URLSessionProxy {

    /// Swizzles the folowing methods:
    ///
    /// - urlSession(_:task:didCompleteWithError:)
    func swizzleDataDataDidCompleteWithError(baseClass: AnyClass) {
        let selector = NSSelectorFromString("_didFinishWithError:")
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
                if let metrics = task.value(forKey: "_incompleteTaskMetrics") as? URLSessionTaskMetrics {
                    #warning("FIX")
                    self?.logger.logTask(task, didFinishCollecting: metrics)
                }
                let error = error as? Error
                self?.logger.logTask(task, didCompleteWithError: error)
            } else {
                NSLog(("Could not get data from _swizzleURLSessionTaskDidCompleteWithError. It might causes due to the latest iOS changes. \(object)")
            }
        }

        method_setImplementation(method, imp_implementationWithBlock(closure))
    }

    /// Swizzles the folowing methods:
    ///
    /// urlSession(_:dataTask:didReceive:)
    func swizzleDataTaskDidReceiveData(baseClass: AnyClass) {
        let selector = NSSelectorFromString("_didReceiveData:")
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
                if let data = data as? Data {
                    self?.logger.logDataTask(task, didReceive: data)
                } else {
                    // TODO: what should it do?
                }
            } else {
                // TODO: update who to call
                NSLog("Could not get data from _swizzleURLSessionDataTaskDidReceiveData. It might causes due to the latest iOS changes. \(object)")
            }
        }
        method_setImplementation(method, imp_implementationWithBlock(closure))
    }
}
