# Network Logging & Debugging

Learn how to enable and configure network logging and debugging.

## Overview

Pulse works on the `URLSession` level, and it needs access to its callbacks to log network requests and capture network metrics. The framework is modular and provides multiple options that can accommodate almost any system. By the end of this article, you will have a system that:

- Captures network requests and metrics
- Supports debugging features powered by Pulse Pro, such as mocking 

## Capture Network Requests

The first step is to capture network traffic.

### Option 1 (Recommended)

Use ``URLSessionProxy``, a thin wrapper on top of `URLSession`. 

```swift
import Pulse

#if DEBUG
let session: URLSessionProtocol = URLSessionProxy(configuration: .default)
#else
let session: URLSessionProtocol = URLSession(configuration: .default)
#endif
```

``URLSessionProxy`` is the best way to integrate Pulse because it supports all `URLSession` APIs, including the new Async/Await methods. It also makes it easy to remove it conditionally.

### Option 2 (Quickest)

If you are evaluating the framework, the quickest way to get started is with a proxy from the **PulseProxy** module.

```swift
import PulseProxy

#if DEBUG
NetworkLogger.enableProxy()
#endif
```

> important: **PulseProxy** uses method swizzling and private APIs, and it is not recommended that you include it in the production builds of your app. It is also not guaranteed to continue working with new versions of the system SDKs.

### Option 3

If you use a delegate-based `URLSession` that doesn't rely on any of its convenience APIs, such as [Alamofire](https://github.com/Alamofire/Alamofire), you can record its traffic using ``URLSessionProxyDelegate``.   

```swift
let delegate = URLSessionProxyDelegate(delegate: <#YourSessionDelegate#>)
let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
```

> important: This method supports a limited subset of scenarios and doesn't work with `URLSession` Async/Await APIs.

### Option 4 (Manual)

If none of the convenience APIs described earlier work for you, you can use the underlying ``NetworkLogger`` directly. For example, here is how you can use it with Alamofire's `EventMonitor`:

```swift
import Alamofire

let session = Alamofire.Session(eventMonitors: [NetworkLoggerEventMonitor()])

struct NetworkLoggerEventMonitor: EventMonitor {
    var logger: NetworkLogger = .shared

    func request(_ request: Request, didCreateTask task: URLSessionTask) {
        logger.logTaskCreated(task)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        logger.logDataTask(dataTask, didReceive: data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        logger.logTask(task, didFinishCollecting: metrics)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        logger.logTask(task, didCompleteWithError: error)
    }
}
```

Alternatively, if you don't have access to `URLSessionTask`, you can store the request/response directly in ``LoggerStore``:

```swift
LoggerStore.shared.storeRequest(urlRequest, response: urlResponse, ...)
```

## Configure Logging

### Record Decoding Errors

The network requests can only be considered successful when the app decodes the response data. With Pulse, you can do just that, and when you open the response body, it'll even highlight the part of the response causing the decoding error.

```swift
// Initial setup
let logger = NetworkLogger {
    $0.isWaitingForDecoding = true
}
let session = NetworkLogger.URLSession(configuration: .default, logger: logger)

// Add this to the code that performs decoding of the responses.
logger.logTask(task, didFinishDecodingWithError: decodingError)
```

### Exclude Information From Logs

``NetworkLogger`` captures data safely in a local database, and it never leaves your device. Logs are never written to the system's logging system. But, of course, logs are meant to be viewed and shared, which is why PulseUI provides sharing options. In case the logs do leave your device, it's best to redact any sensitive information. 

``NetworkLogger/Configuration`` has a set of convenience APIs for managing what information is included or excluded from the logs.

```swift
let logger = NetworkLogger {
    // Includes only requests with the given domain.
    $0.includedHosts = ["*.example.com"]

    // Exclude some subdomains.
    $0.excludedHosts = ["logging.example.com"]

    // Exclude specific URLs.
    $0.excludedURLs = ["*/log/event"]

    // Replaces values for the given HTTP headers with "<private>"
    $0.sensitiveHeaders = ["Authorization", "Access-Token"]

    // Redacts sensitive query items.
    $0.sensitiveQueryItems = ["password"]

    // Replaces values for the given response and request JSON fields with "<private>"
    $0.sensitiveDataFields = ["password"]
}
```

You can then replace the default decoder with your custom instance:

```swift
NetworkLogger.shared = logger
```

> Tip: "Include" and "exclude" patterns support basic wildcards (`*`), but you can also turn them into full-featured regex patterns using ``NetworkLogger/Configuration/isRegexEnabled``. 

If the built-in configuration options don't cover all of your use cases, you can set the ``NetworkLogger/Configuration/willHandleEvent`` closure that provides you complete control for filtering out and updating the events.

> important: If you redact information manually from requests or responses, also update ``NetworkLogger/Metrics`` because individual transactions within metrics contain recorded request and response pairs.

### Trace in Xcode Console

Pulse doesn't print anything in the Xcode Console by default, but it's easy to enable  logging for network requests. ``LoggerStore`` re-translates all of the log events that it processes using ``LoggerStore/events`` publisher that you can leverage.

```swift
func register(store: LoggerStore) {
    cancellable = store.events.receive(on: queue).sink { [weak self] in
        self?.process(event: $0)
    }
}

private func process(event: LoggerStore.Event) {
    switch event {
    case .networkTaskCompleted(let event):
        // Log any information you need from event in any format you like.
    default:
        break
    }
}
```

## Network Debugging

In addition to logging, Pulse provides network debugging features, such as logging. If you use the recommended ``URLSessionProxy``, these features are enabled automatically, and you don't need to do anything. In other cases, make sure to inject ``MockingURLProtocol`` in the set of URL protocols used by your `URLSession`:

```swift
let configuration = URLSesionConfiguration.default
configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
```

Alternatively, you can use automatic registration.

```swift
MockingURLProtocol.enableAutomaticRegistration()
```
