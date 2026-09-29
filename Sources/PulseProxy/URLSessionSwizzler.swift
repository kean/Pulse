// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse

extension NetworkLogger {
    /// Enables automatic logging and remote debugging of network requests.
    ///
    /// - warning: This method of logging relies heavily on swizzling and might
    /// stop working in the future versions of the native SDKs. If you are looking
    /// for a more stable solution, consider using ``URLSessionProxyDelegate`` or
    /// manually logging the requests using ``NetworkLogger``.
    ///
    /// - parameter logger: The network logger to be used for recording the requests. By default, uses shared logger.
    public static func enableProxy(logger: NetworkLogger? = nil) {
        URLSessionSwizzler.enable(logger: logger)
    }
}

final class URLSessionSwizzler {
    static var shared: URLSessionSwizzler?

    private var logger: NetworkLogger { _logger ?? .shared }
    private let _logger: NetworkLogger?

    init(logger: NetworkLogger?) {
        self._logger = logger
    }

    static let lock = NSLock()
    static var isEnabled = false

    static func enable(logger: NetworkLogger?) {
        lock.lock()
        if isEnabled {
            lock.unlock()
            NSLog("Error: Pulse proxy is already enabled")
            return
        }
        isEnabled = true
        lock.unlock()

        let proxy = URLSessionSwizzler(logger: logger)
        proxy.enable()
        URLSessionSwizzler.shared = proxy
    }

    func enable() {
        swizzleURLSessionTaskResume()
        swizzleUploadTaskFromData()
        // "__NSCFURLLocalSessionConnection"
        if let sessionClass = NSClassFromString(["__", "NS", "CFURL", "Local", "Session", "Connection"].joined()) {
            swizzleDataTaskDidReceiveData(baseClass: sessionClass)
            swizzleDataDataDidCompleteWithError(baseClass: sessionClass)
        } else {
            NSLog("Pulse.URLSessionSwizzler failed to initialize. Please report at https://github.com/kean/Pulse/issues.")
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
                BodyStreamHook.installIfNeeded(for: task)

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
                if var error = error as? NSError {
                    if error.domain == "kCFErrorDomainCFNetwork" {
                        // Satisfy LogggerStore (needs refactoring)
                        error = NSError(domain: URLError.errorDomain, code: error.code, userInfo: error.userInfo)
                    }
                    self?.logger.logTask(task, didCompleteWithError: error)
                } else {
                    self?.logger.logTask(task, didCompleteWithError: error as? Error)
                }
                RequestBodyCapture.existing(for: task)?.cancelAll()
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

    // - `uploadTask(with:from:)`, `uploadTask(with:from:completionHandler:)`, and
    // `upload(for:from:delegate:)`. URLSession keeps these bodies out of
    // `originalRequest.httpBody`, so attach them to the task instead.
    private func swizzleUploadTaskFromData() {
        typealias Handler = AnyObject // The completion handler block, passed through as is
        do {
            let selector = NSSelectorFromString("uploadTaskWithRequest:fromData:")
            if let method = class_getInstanceMethod(URLSession.self, selector) {
                typealias MethodSignature = @convention(c) (AnyObject, Selector, NSURLRequest, NSData?) -> URLSessionUploadTask
                let original = unsafeBitCast(method_getImplementation(method), to: MethodSignature.self)
                let block: @convention(block) (AnyObject, NSURLRequest, NSData?) -> URLSessionUploadTask = { [weak self] session, request, data in
                    let task = original(session, selector, request, data)
                    self?.logger.attachRequestBody(data as Data?, to: task)
                    return task
                }
                method_setImplementation(method, imp_implementationWithBlock(block))
            }
        }
        do {
            let selector = NSSelectorFromString("uploadTaskWithRequest:fromData:completionHandler:")
            if let method = class_getInstanceMethod(URLSession.self, selector) {
                typealias MethodSignature = @convention(c) (AnyObject, Selector, NSURLRequest, NSData?, Handler?) -> URLSessionUploadTask
                let original = unsafeBitCast(method_getImplementation(method), to: MethodSignature.self)
                let block: @convention(block) (AnyObject, NSURLRequest, NSData?, Handler?) -> URLSessionUploadTask = { [weak self] session, request, data, handler in
                    let task = original(session, selector, request, data, handler)
                    self?.logger.attachRequestBody(data as Data?, to: task)
                    return task
                }
                method_setImplementation(method, imp_implementationWithBlock(block))
            }
        }
        do {
            // "_uploadTaskWithRequest:fromData:delegate:completionHandler:" (used by `upload(for:from:delegate:)`)
            let selector = NSSelectorFromString(["_", "upload", "TaskWithRequest:", "fromData:", "delegate:", "completionHandler:"].joined())
            if let method = class_getInstanceMethod(URLSession.self, selector) {
                typealias MethodSignature = @convention(c) (AnyObject, Selector, NSURLRequest, NSData?, AnyObject?, Handler?) -> URLSessionUploadTask
                let original = unsafeBitCast(method_getImplementation(method), to: MethodSignature.self)
                let block: @convention(block) (AnyObject, NSURLRequest, NSData?, AnyObject?, Handler?) -> URLSessionUploadTask = { [weak self] session, request, data, delegate, handler in
                    let task = original(session, selector, request, data, delegate, handler)
                    self?.logger.attachRequestBody(data as Data?, to: task)
                    return task
                }
                method_setImplementation(method, imp_implementationWithBlock(block))
            }
        }
    }
}

// MARK: - Streamed Request Bodies

/// Captures bodies of `uploadTask(withStreamedRequest:)` tasks by hooking
/// `urlSession(_:task:needNewBodyStream:)` on the class that implements it and
/// teeing the returned stream.
enum BodyStreamHook {
    static let needNewBodyStream = NSSelectorFromString("URLSession:task:needNewBodyStream:")
    static let needNewBodyStreamFromOffset = NSSelectorFromString("URLSession:task:needNewBodyStreamFromOffset:completionHandler:")

    private static let lock = NSLock()
    nonisolated(unsafe) private static var hooked = Set<String>()
    private static let reentrancyKey = "com.github.kean.pulse.needNewBodyStream"

    /// Called from the `resume` hook, before URLSession asks for the first stream.
    static func installIfNeeded(for task: URLSessionTask) {
        guard task is URLSessionUploadTask,
              let request = task.originalRequest,
              request.httpBody == nil, request.httpBodyStream == nil,
              task.pulse_requestBody == nil else {
            return
        }
        // The task delegate is asked first; the session delegate if the task
        // delegate doesn't implement the method.
        var delegates: [AnyObject] = []
        if let delegate = task.delegate {
            delegates.append(delegate)
        }
        if task.responds(to: NSSelectorFromString("session")),
           let session = task.value(forKey: "session") as? URLSession,
           let delegate = session.delegate {
            delegates.append(delegate)
        }
        for delegate in delegates {
            for selector in [needNewBodyStream, needNewBodyStreamFromOffset] {
                if let target = implementor(of: selector, startingAt: delegate) {
                    install(selector, on: type(of: target))
                }
            }
        }
    }

    /// Follows `forwardingTarget(for:)` (used by `URLSessionProxyDelegate` and
    /// similar proxies) to the object that actually implements `selector`.
    private static func implementor(of selector: Selector, startingAt object: AnyObject) -> AnyObject? {
        var current = object
        for _ in 0..<4 {
            if class_getInstanceMethod(type(of: current), selector) != nil {
                return current
            }
            guard let proxy = current as? NSObject, proxy.responds(to: selector),
                  let target = proxy.forwardingTarget(for: selector) as AnyObject?,
                  target !== current else {
                return nil
            }
            current = target
        }
        return nil
    }

    /// Returns the class in the hierarchy that defines `selector`, so that an
    /// inherited implementation is hooked once, on the class that owns it.
    private static func owner(of selector: Selector, in cls: AnyClass) -> AnyClass? {
        var next: AnyClass? = cls
        while let current = next {
            var count: UInt32 = 0
            if let methods = class_copyMethodList(current, &count) {
                defer { free(methods) }
                if (0..<Int(count)).contains(where: { method_getName(methods[$0]) == selector }) {
                    return current
                }
            }
            next = class_getSuperclass(current)
        }
        return nil
    }

    private static func install(_ selector: Selector, on cls: AnyClass) {
        guard let owner = owner(of: selector, in: cls),
              let method = class_getInstanceMethod(owner, selector) else {
            return
        }
        lock.lock()
        defer { lock.unlock() }
        guard hooked.insert("\(NSStringFromClass(owner)) \(NSStringFromSelector(selector))").inserted else {
            return
        }
        typealias Completion = @convention(block) (InputStream?) -> Void
        if selector == needNewBodyStream {
            typealias MethodSignature = @convention(c) (AnyObject, Selector, URLSession, URLSessionTask, Completion) -> Void
            let original = unsafeBitCast(method_getImplementation(method), to: MethodSignature.self)
            let block: @convention(block) (AnyObject, URLSession, URLSessionTask, @escaping Completion) -> Void = { object, session, task, completion in
                intercept(task: task, offset: 0, completion: completion) {
                    original(object, selector, session, task, $0)
                }
            }
            method_setImplementation(method, imp_implementationWithBlock(block))
        } else {
            typealias MethodSignature = @convention(c) (AnyObject, Selector, URLSession, URLSessionTask, Int64, Completion) -> Void
            let original = unsafeBitCast(method_getImplementation(method), to: MethodSignature.self)
            let block: @convention(block) (AnyObject, URLSession, URLSessionTask, Int64, @escaping Completion) -> Void = { object, session, task, offset, completion in
                intercept(task: task, offset: offset, completion: completion) {
                    original(object, selector, session, task, offset, $0)
                }
            }
            method_setImplementation(method, imp_implementationWithBlock(block))
        }
    }

    /// Wraps the completion so that the stream is teed. A nested call (a
    /// subclass calling `super` when both classes are hooked) passes through.
    private static func intercept(
        task: URLSessionTask,
        offset: Int64,
        completion: @escaping @convention(block) (InputStream?) -> Void,
        call: (@escaping @convention(block) (InputStream?) -> Void) -> Void
    ) {
        let threadDictionary = Thread.current.threadDictionary
        guard threadDictionary[reentrancyKey] == nil,
              let limit = URLSessionSwizzler.shared?.requestBodySizeLimit else {
            return call(completion)
        }
        threadDictionary[reentrancyKey] = true
        defer { threadDictionary[reentrancyKey] = nil }

        let attempt = RequestBodyCapture.capture(for: task).startAttempt(offset: offset)
        call { stream in
            // A delegate can answer after the task ended, and URLSession then
            // drops the stream without opening or closing it.
            guard let stream, !task.hasEnded else {
                return completion(stream)
            }
            completion(StreamTee.tee(stream, attempt: attempt, limit: limit))
            if task.hasEnded { // It ended while the tee was set up
                attempt.capture.cancelAll()
            }
        }
    }
}

private extension URLSessionTask {
    var hasEnded: Bool {
        state == .canceling || state == .completed
    }
}

extension URLSessionSwizzler {
    var requestBodySizeLimit: Int { logger.requestBodySizeLimit }
}

/// The streamed body attempts of a single task. A redirect or an authentication
/// retry starts a new attempt, whose body replaces the previous one once it's
/// read to the end, so an attached body is never partial. A resumed upload
/// (`needNewBodyStreamFromOffset`) reuses the prefix read by the previous attempt.
final class RequestBodyCapture: @unchecked Sendable {
    final class Attempt: @unchecked Sendable {
        let capture: RequestBodyCapture
        let generation: Int
        /// The bytes before the stream's offset, or `nil` if they are unknown.
        let prefix: Data?

        init(capture: RequestBodyCapture, generation: Int, prefix: Data?) {
            self.capture = capture
            self.generation = generation
            self.prefix = prefix
        }
    }

    private let lock = NSLock()
    private weak var task: URLSessionTask?
    private var generation = 0
    private var latestBytes: Data? = Data() // Bytes read by the latest attempt, from offset 0
    private var tees: [ObjectIdentifier: StreamTee] = [:]

    private init(task: URLSessionTask) {
        self.task = task
    }

    nonisolated(unsafe) private static var key: UInt8 = 0
    private static let lock = NSLock()

    static func capture(for task: URLSessionTask) -> RequestBodyCapture {
        lock.lock()
        defer { lock.unlock() }
        if let capture = objc_getAssociatedObject(task, &key) as? RequestBodyCapture {
            return capture
        }
        let capture = RequestBodyCapture(task: task)
        objc_setAssociatedObject(task, &key, capture, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return capture
    }

    static func existing(for task: URLSessionTask) -> RequestBodyCapture? {
        lock.lock()
        defer { lock.unlock() }
        return objc_getAssociatedObject(task, &key) as? RequestBodyCapture
    }

    func startAttempt(offset: Int64) -> Attempt {
        lock.lock()
        defer { lock.unlock() }
        generation += 1
        var prefix: Data? = Data()
        if offset > 0 {
            prefix = latestBytes.flatMap { $0.count >= offset ? $0.prefix(Int(offset)) : nil }
        }
        return Attempt(capture: self, generation: generation, prefix: prefix)
    }

    func register(_ tee: StreamTee) {
        lock.lock()
        tees[ObjectIdentifier(tee)] = tee
        lock.unlock()
    }

    /// - parameter bytes: The bytes read from the stream, or `nil` if the body exceeded the limit.
    func finish(_ attempt: Attempt, tee: StreamTee, bytes: Data?, isComplete: Bool) {
        lock.lock()
        defer { lock.unlock() }
        tees[ObjectIdentifier(tee)] = nil
        guard attempt.generation == generation else {
            return // Superseded by a newer attempt
        }
        latestBytes = attempt.prefix.flatMap { prefix in bytes.map { prefix + $0 } }
        if isComplete {
            task?.pulse_requestBody = latestBytes
        }
    }

    /// Stops the attempts that URLSession abandoned without closing their streams.
    func cancelAll() {
        lock.lock()
        let tees = Array(self.tees.values)
        lock.unlock()
        tees.forEach { $0.cancel() }
    }
}

/// Copies an input stream into a bound stream pair while recording the bytes.
///
/// All tees run on a single thread driven by a run loop; no call ever blocks,
/// so an abandoned stream can always be closed.
final class StreamTee: NSObject, StreamDelegate, @unchecked Sendable {
    private static let thread: Thread = {
        let thread = Thread {
            let runLoop = RunLoop.current
            runLoop.add(NSMachPort(), forMode: .default) // Keeps the run loop alive
            while true {
                runLoop.run(mode: .default, before: .distantFuture)
            }
        }
        thread.name = "com.github.kean.pulse.stream-tee"
        thread.start()
        return thread
    }()

    private let source: InputStream
    private let output: OutputStream
    private let attempt: RequestBodyCapture.Attempt
    private let limit: Int
    private var pending = Data()
    private var bytes: Data? = Data()
    private var isSourceAtEnd = false
    private var isFinished = false

    static func tee(_ source: InputStream, attempt: RequestBodyCapture.Attempt, limit: Int) -> InputStream {
        var input: InputStream?
        var output: OutputStream?
        Stream.getBoundStreams(withBufferSize: 64 * 1024, inputStream: &input, outputStream: &output)
        guard let input, let output else {
            return source
        }
        let tee = StreamTee(source: source, output: output, attempt: attempt, limit: limit)
        attempt.capture.register(tee)
        tee.perform(#selector(start), on: thread, with: nil, waitUntilDone: false)
        return input
    }

    private init(source: InputStream, output: OutputStream, attempt: RequestBodyCapture.Attempt, limit: Int) {
        self.source = source
        self.output = output
        self.attempt = attempt
        self.limit = limit
    }

    func cancel() {
        perform(#selector(_cancel), on: Self.thread, with: nil, waitUntilDone: false)
    }

    @objc private func _cancel() {
        finish(isComplete: false)
    }

    @objc private func start() {
        for stream in [source, output] as [Stream] {
            stream.delegate = self
            stream.schedule(in: .current, forMode: .default)
            stream.open()
        }
    }

    func stream(_ stream: Stream, handle event: Stream.Event) {
        if event.contains(.errorOccurred) {
            return finish(isComplete: false)
        }
        if stream === output, event.contains(.endEncountered) {
            return finish(isComplete: false) // The reader went away
        }
        if stream === source, event.contains(.endEncountered) {
            isSourceAtEnd = true
        }
        pump()
    }

    private func pump() {
        while !isFinished {
            if pending.isEmpty {
                if !isSourceAtEnd, source.hasBytesAvailable {
                    var buffer = [UInt8](repeating: 0, count: 16 * 1024)
                    let count = source.read(&buffer, maxLength: buffer.count)
                    if count < 0 {
                        return finish(isComplete: false)
                    }
                    if count == 0 {
                        isSourceAtEnd = true
                        continue
                    }
                    pending.append(buffer, count: count)
                    if let size = bytes?.count, size + count < limit {
                        bytes?.append(buffer, count: count)
                    } else {
                        bytes = nil // Too large to store
                    }
                } else if isSourceAtEnd || source.streamStatus == .atEnd {
                    return finish(isComplete: true)
                } else {
                    return // Wait for `.hasBytesAvailable`
                }
            }
            guard output.hasSpaceAvailable else {
                return // Wait for `.hasSpaceAvailable`
            }
            let written = pending.withUnsafeBytes {
                output.write($0.bindMemory(to: UInt8.self).baseAddress!, maxLength: pending.count)
            }
            if written <= 0 {
                return finish(isComplete: false)
            }
            pending.removeFirst(written)
        }
    }

    private func finish(isComplete: Bool) {
        guard !isFinished else { return }
        isFinished = true
        // Record the body before closing the stream so that it lands before
        // URLSession completes the task.
        attempt.capture.finish(attempt, tee: self, bytes: bytes, isComplete: isComplete)
        for stream in [source, output] as [Stream] {
            stream.delegate = nil
            stream.remove(from: .current, forMode: .default)
            stream.close()
        }
    }
}
