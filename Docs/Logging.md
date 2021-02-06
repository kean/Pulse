# Network Requests Logging

- [Network Requests Logging](#network-requests-logging)
  * [1. Logging System Bootstrap](#1-logging-system-bootstrap)
  * [2. Recording Network Logs](#2-recording-network-logs)
  * [2.1. Automatic Logging](#21-automatic-logging)
  * [2.2. Alamofire Integration](#22-alamofire-integration)
  * [2.3. Manual Integration](#23-manual-integration)

Pulse is designed to be as least intrusive as possible. It doesn't use swizzling, it doesn't create custom URL protocols. It does only what you ask it to without the risk of interfering with your network communications.

## 1. Logging System Bootstrap

The primary component that you will use to log network requests is `NetworkLogger` which is part of `PulseUI` framework. It's easy to setup.

```swift
import Pulse
import PulseUI
import Logging

// 1. Setup the logging system to use Pulse.PersistentLogHandler
LoggingSystem.bootstrap(PersistentLogHandler.init)

// 2. Create NetworkLogger
let logger = NetworkLogger()
```

> If you want to use `NetworkLogger` with a custom logger (without using `LoggingSystem.bootstrap`), please refer to [SwiftLog](https://github.com/apple/swift-log) documentation.

The logs are stored in a database. The request and response bodies are deduplicated and stored in the file system. Old messages and responses are removed when the size limit is reached. For customization options, please refer to `NetworkLogger` inline documentation.

## 2. Recording Network Logs

There are multiple options for logging network requests using Pulse.

### 2.1. Automatic Logging

Use `URLSessionProxyDelegate` to automatically store all of the requried events.

```swift
let urlSession = URLSession(configuration: .default, delegate: URLSessionProxyDelegate(logger: logger, delegate: self), delegateQueue: nil)

// Use `URLSession` as usual.
```

> `URLSessionProxyDelegate` is extremely small and simply uses `responds(to:)` and `forwardingTarget(for:)` methods to forward selectors to the actual session delegate when needed.

### 2.2. Alamofire Integration

While you can use `PulseUI.URLSessionProxyDelegate`, the recommended approach is to use `Alamofire.EventMonitor`.

```swift
import Alamofire

// Don't forget to bootstrap the logging systme first.

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

### 2.3. Manual Integration

If none of the previous options work for you, you can use `NetworkLogger` directly to log the network events. While technically none of the logs are required, you want to the very least log data, metrics, and completion events.

```swift
final class NetworkLogger {
    func logTaskCreated(_ task: URLSessionTask)
    func logDataTask(_ dataTask: URLSessionDataTask, didReceive response: URLResponse)
    func logDataTask(_ dataTask: URLSessionDataTask, didReceive data: Data)
    func logTask(_ task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics)
    func logTask(_ task: URLSessionTask, didCompleteWithError error: Error?)
}
```
