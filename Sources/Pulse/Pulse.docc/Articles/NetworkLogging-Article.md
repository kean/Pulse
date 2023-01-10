# Logging Network Requests

Learn how to enable network logging.

## Overview

Pulse works on the `URLSession` level and it needs access to its callbacks to log network requests and capture network metrics. There are multiple ways to do that and they are all covered in this article.

## Proxy Delegate

The recommended option is to use ``URLSessionProxyDelegate`` which sits between [`URLSession`](https://developer.apple.com/documentation/foundation/urlsession) and your actual [`URLSessionDelegate`](https://developer.apple.com/documentation/foundation/urlsessiondelegate).

You can enable ``URLSessionProxyDelegate`` for all `URLSession` instances created by the app by using ``URLSessionProxyDelegate/enableAutomaticRegistration(logger:)`` (note that it uses Objective-C runtime to achieve that):

```swift
// Call it anywhere in your code prior to instantiating a `URLSession`
URLSessionProxyDelegate.enableAutomaticRegistration()

// Instantiate `URLSession` as usual
let session = URLSession(configuration: .default, delegate: YourURLSessionDelegate(), delegateQueue: nil)
```

And if you want to enable logging just for specific sessions, use ``URLSessionProxyDelegate`` directly:

```swift
let delegate = URLSessionProxyDelegate(delegate: YourURLSessionDelegate())
let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
```

> important: Both these options work only with sessions that use a delegate-based approach and won't work with `URLSession.shared`. In that can you can either log the requests manually, which is covered in the next section or try ``Experimental/URLSessionProxy``.

## Manual Logging

Another option for capturing network requests is by using ``NetworkLogger`` directly. For example, here can you can use it with Alamofire's `EventMonitor`:

```swift
import Alamofire

// Don't forget to bootstrap the logging system first.

let session = Alamofire.Session(eventMonitors: [NetworkLoggerEventMonitor(logger: logger)])

struct NetworkLoggerEventMonitor: EventMonitor {
    let logger: NetworkLogger

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

> tip: Make sure to capture [`URLSessionTaskMetrics`](https://developer.apple.com/documentation/foundation/urlsessiontaskmetrics) as Pulse makes a great use of them and many of the features won't work without them.

## Session Proxy (Experimental)

To capture _all_ network traffic from _all_ session, including `URLSession.shared`, you can try using ``Experimental/URLSessionProxy``.

```swift
Experimental.URLSessionProxy.shared.isEnabled = true
```

> warning: As clearly communicate by its namespace, it's an experimental feature and it might negatively affect your networking. The way it works is by registering a custom [URLProtocol](https://developer.apple.com/documentation/foundation/urlprotocol) and using a secondary URLSession instance in it, but it can be a useful tool.

> note: Alternatively, you can give the following swizzle-based [approach](https://gist.github.com/kean/3154a5bde8e0c5e9dc3322f21ba86757) a try that is less intrusive but requires more swizzling and can't be shipped with the production code.

## Recoding Decoding Errors

The network requests usually can only be considered successful when the app was able to decode the response data. With Pulse, you can do just that and when you open the response body, it'll even highlight the part of the response that's causing the decoding error.

```swift
// Initial setup
let logger = NetworkLogger(configuration: .init(isWaitingForDecoding: true))
let delegate = URLSessionProxyDelegate(logger: logger, delegate: YourURLSessionDelegate()))
// ... create session

// Somewhere else in the app where decoding is done.
logger.logTask(task, didFinishDecodingWithError: decodingError)
```

## Exclude Information From Logs

There is usually some sensitive information in network requests, such as passwords, access tokens, and more. It's important to keep it safe.

> tip: It's recommended to use Pulse _only_ in the debug mode.

``NetworkLogger`` captures data safely in a local database and it never leaves your device. Logs are never written to the system's logging system. But of course, logs are meant to be viewed and shared, which is why PulseUI provides sharing options. In case the logs do leave your device, it's best to redact any sensitive information. 

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

> tip: "Include" and "exclude" patterns support basic wildcards (`*`), but you can also turns them into full-featured regex patterns using ``NetworkLogger/Configuration/isRegexEnabled``. 

If the built-in configuration options don't cover all of your use-cases, you can set  ``NetworkLogger/Configuration/willHandleEvent`` closure that provides you complete control for filtering out and updating the events.

> important: If you redact information manually from requests or responses, make sure to also update ``NetworkLogger/Metrics`` because individual transactions within metrics contain recorded request and response pairs.

## Trace in Xcode Console

While Pulse doesn't print anything in the Xcode Console by default, it's easy to enable such logging for network requests. ``LoggerStore`` re-translates all of the log events that it processes using ``LoggerStore/events`` publisher that you can leverage to log some of the recoded information in the Xcode Console.

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
