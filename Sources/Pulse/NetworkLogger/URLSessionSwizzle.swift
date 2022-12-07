// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import ObjectiveC.runtime

public extension Experimental {

    private static var networkLogger = NetworkLogger()

    private static func swizzleReceiveData() {
        let selector = NSSelectorFromString("_didReceiveData:")
        let klass: AnyClass = NSClassFromString("__NSCFURLLocalSessionConnection")!
        
        let originalImp = class_getMethodImplementation(klass, selector)
        typealias IMPType = @convention(c) (AnyObject, Selector, AnyObject) -> Void
        let originalImpCallable = unsafeBitCast(originalImp, to: IMPType.self)

        let block: @convention(block) (AnyObject, AnyObject) -> Void = {
            if let this = $0 as? NSObject, let task = this.value(forKey: "task") as? URLSessionDataTask, let data = $1 as? Data {
                Experimental.networkLogger.logDataTask(task, didReceive: data)
            }
            originalImpCallable($0, selector, $1)
        }
        
        setNewIMPWithBlock(block, forSelector: selector, toClass: klass)
    }

    private static func swizzleInit() {
        let selector = NSSelectorFromString("initWithTask:delegate:delegateQueue:")
        let klass: AnyClass = NSClassFromString("__NSCFURLLocalSessionConnection")!
        
        let originalImp = class_getMethodImplementation(klass, selector)
        typealias IMPType = @convention(c) (AnyObject, Selector, AnyObject, AnyObject, AnyObject) -> AnyObject
        let originalImpCallable = unsafeBitCast(originalImp, to: IMPType.self)

        let block: @convention(block) (AnyObject, AnyObject, AnyObject, AnyObject) -> AnyObject = {
            if let task = $1 as? URLSessionTask {
                Experimental.networkLogger.logTaskCreated(task)
            }
            return originalImpCallable($0, selector, $1, $2, $3)
        }
        
        setNewIMPWithBlock(block, forSelector: selector, toClass: klass)
    }

    private static func swizzleFinishWithError() {
        let selector = NSSelectorFromString("_didFinishWithError:")
        let klass: AnyClass = NSClassFromString("__NSCFURLLocalSessionConnection")!
        
        let originalImp = class_getMethodImplementation(klass, selector)
        typealias IMPType = @convention(c) (AnyObject, Selector, AnyObject?) -> Void
        let originalImpCallable = unsafeBitCast(originalImp, to: IMPType.self)

        let block: @convention(block) (AnyObject, AnyObject?) -> Void = {
            if let this = $0 as? NSObject,
                let task = this.value(forKey: "task") as? URLSessionTask,
                let metrics = task.value(forKey: "_incompleteTaskMetrics") as? URLSessionTaskMetrics {
                Experimental.networkLogger.logTask(task, didFinishCollecting: metrics)
            }
            
            if let this = $0 as? NSObject, let task = this.value(forKey: "task") as? URLSessionTask, let error = $1 as? (Error?) {
                Experimental.networkLogger.logTask(task, didCompleteWithError: error)
            }
            
            originalImpCallable($0, selector, $1)
        }
        
        setNewIMPWithBlock(block, forSelector: selector, toClass: klass)
    }

    private static func setNewIMPWithBlock<T>(_ block: T, forSelector selector: Selector, toClass klass: AnyClass) {
        let method = class_getInstanceMethod(klass, selector)
        let imp = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
        if !class_addMethod(klass, selector, imp, method_getTypeEncoding(method!)) {
            method_setImplementation(method!, imp)
        }
    }

    static func swizzleURLSession() {
        swizzleInit()
        swizzleReceiveData()
        swizzleFinishWithError()
    }
    
}

