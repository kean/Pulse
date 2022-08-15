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

## Redacting Sensitive Data

There is usually a lot of sensitive information in network requests, such as passwords, access tokens, user information, and more. It's important to keep this information safe.

> tip: It's recommended to enable Pulse and its Console _only_ in the debug mode and never in production. 

Pulse captures the logged information safely in its internal database and it never leaves your device. Nothing is ever written to the system's logging system, so it won't appear in the Console. But of course, logs are meant to be viewed and shared. For example, QA might be testing your debug app with a Pulse console built-in and they'll want to export the logs from the device, which they easily can do. You might want to make sure the sensitive information is redacted in that case.

Both ``NetworkLogger`` and ``LoggerStore`` can be configured with a ``NetworkLogger/Configuration/willHandleEvent`` closure that can be used to filter out the sensitive events. You can either return `nil` to prevent the response from ever being recorded or modify the event before returning it.

```swift
var configuration = NetworkLogger.Configuration()
configuration.willHandleEvent = { event in
    switch event {
    case .networkTaskCreated(let event):
        var event = event
        event.originalRequest = event.originalRequest.redactingSensitiveHeaders(["Authorization"])
        event.currentRequest = event.currentRequest?.redactingSensitiveHeaders(["Authorization"])
        return .networkTaskCreated(event)
    case .networkTaskCompleted(let event):
        // Repeat the same for .networkTaskCompleted 
    default:
        return event
    }
}
```

> important: If you do decide to redact some information from requests or responses, make sure to also update ``NetworkLogger/Metrics`` because individual transactions within metrics contain recorded request and response pairs.

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
