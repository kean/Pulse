![pulse-small](https://user-images.githubusercontent.com/1567433/106982746-a6d5fe80-6732-11eb-8202-796d8e62db13.png)

<p align="left">
<img src="https://img.shields.io/badge/platforms-iOS%2C%20macOS%2C%20watchOS%2C%20tvOS-lightgrey.svg">
<img src="https://github.com/kean/Pulse/workflows/CI/badge.svg">
</p>

**Pulse** is a logging system with structured persistent storage.

**PulseUI** allows you to quickly preview logs in your iOS or tvOS apps. Share logs, and use Pulse macOS app to search and filter them. Inspect all of your app's network traffic. **PulseUI** is available for [**GitHub sponsors**](https://github.com/sponsors/kean) and will be open sourced when there are enough sponsors behind it.

### To learn more about Pulse, see the [introductory post](https://kean.blog/post/pulse) and see [a demo](https://www.youtube.com/watch?v=17oQ9MF8Pq8).

<br/>

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

<br/>

### iOS Console

Build a console right into your iOS apps.

<img width="320" alt="Screen Shot 2020-05-04 at 13 50 26" src="https://user-images.githubusercontent.com/1567433/106993151-19050e00-6748-11eb-8135-cfd505f9625d.png"> <img width="320" alt="Screen Shot 2020-05-04 at 10 43 28" src="https://user-images.githubusercontent.com/1567433/106415190-703f7180-641c-11eb-8f0a-2cc2ec189f79.png">

<br/>

### macOS App

Share your Pulse database and view it on your Mac. Use advanced search to filter your messages.

<img width="706" alt="Screen Shot 2020-05-05 at 10 47 53" src="https://user-images.githubusercontent.com/1567433/106982302-d0daf100-6731-11eb-83f7-8e483c65745d.png">


# Minimum Requirements

| Pulse          | Swift           | Xcode           | Platforms                                         |
|---------------|-----------------|-----------------|---------------------------------------------------|
| Pulse 0.3      | Swift 5.2       | Xcode 11.3      | iOS 11.0 / watchOS 4.0 / macOS 10.13 / tvOS 11.0  |

# License

Pulse is available under the MIT license. See the LICENSE file for more info.

