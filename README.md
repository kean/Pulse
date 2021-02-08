<img width="309" alt="Untitled-3" src="https://user-images.githubusercontent.com/1567433/107172577-b1430300-6993-11eb-939c-18620c00e2a1.png">

<p align="left">
<img src="https://img.shields.io/badge/platforms-iOS%2C%20macOS%2C%20watchOS%2C%20tvOS-lightgrey.svg">
<img src="https://github.com/kean/Pulse/workflows/CI/badge.svg">
</p>

<hr/>

**Pulse** is a structured logging system. Record and inspect network requests and logs right from your iOS app using Pulse Console. Share and view logs in Pulse macOS app. Logs are recoded locally and never leave your device.

> **PulseUI** is available for [**GitHub sponsors**](https://github.com/sponsors/kean) and will be available for free when the target number of sponsors is reached.

<br/>

![pulse-01-console](https://user-images.githubusercontent.com/1567433/107236825-129abe80-69f4-11eb-976a-4b5bc9dc383d.png)

<br/>

![pulse-02-inspector](https://user-images.githubusercontent.com/1567433/107172234-cf5c3380-6992-11eb-89a5-b77a78c09ec4.png)

<br/>

![pulse-03-share](https://user-images.githubusercontent.com/1567433/107172237-cf5c3380-6992-11eb-8459-83be62c16be0.png)

<br/>

![pulse-04-platforms](https://user-images.githubusercontent.com/1567433/107236017-475a4600-69f3-11eb-82d2-a0e11b760dd6.png)

# About

Pulse **is not** a network debugging proxy tool like Proxyman, Charles, or Wireshark. It *won't* automatically intercept all network traffic coming from your app or device. 

Pulse **is** an iOS-first framework you integrate it into your app. It can record events from `URLSession` or from frameworks that use it, such as `Alamofire` You can either record the events manually or by using convenience `URLSessionProxyDelegate`.

The main advantages of Pulse it is integrated directly into your app and is always recording (when your code tells it to) and is available for everyone who uses the build. You or your QA team can view the logs on the device and easily share them and attach to your tickets. The logs never leave the device.

# Usage

The primary class in Pulse is `PersistentLogHandler` which can be used as a logging backend for [SwiftLog](https://github.com/apple/swift-log).

#### Bootstrapping

```swift
LoggingSystem.bootstrap(PersistentLogHandler.init)
```

If you are not using [SwiftLog](https://github.com/apple/swift-log) in your project, you can use `Pulse.PersistentLogHandler` directly without the need for bootstrapping.

#### Logging

Use SwiftLog [as usual](https://github.com/apple/swift-log#lets-log) to start logging messages.

```swift
let logger = Logger(label: "com.yourcompany.yourapp")

/// ...

logger.info("This message will be stored persistently")
```

#### Logging Network Request

Pulse supports logging [`URLSession`](https://developer.apple.com/documentation/foundation/urlsession) tasks and offers a simple [Alamofire](https://github.com/Alamofire/Alamofire) integration.

> For more information, please follow the [dedicated guide](https://github.com/kean/Pulse/blob/0.6.0/Docs/Logging.md).

#### Storage

All logged messages are stored persistently using Core Data, including metadata and other information. You get full access to all of the recorded messages at any time using `LoggerMessageStore`.

```swift
let message = try LoggerMessageStore.default.allMessage()

// NSPersistentStoreContainer
let container = logger.store.container
```

<br/>

# [PulseUI](https://github.com/kean/PulseUI)

**PulseUI** allows you to quickly preview logs in your iOS or tvOS apps. Share logs, and use Pulse macOS app to search and filter them. **PulseUI** is available for [**GitHub sponsors**](https://github.com/sponsors/kean).

### iOS Console

Build a console right into your iOS apps.

### macOS App

Share your Pulse database and view it on your Mac. Use advanced search to filter your messages.


# Minimum Requirements

| Pulse          | Swift           | Xcode           | Platforms                                         |
|---------------|-----------------|-----------------|---------------------------------------------------|
| Pulse 0.3      | Swift 5.2       | Xcode 11.3      | iOS 11.0 / watchOS 4.0 / macOS 10.13 / tvOS 11.0  |

# License

Pulse is available under the MIT license. See the LICENSE file for more info.

