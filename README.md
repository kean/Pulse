<img width="309" alt="Untitled-3" src="https://user-images.githubusercontent.com/1567433/107172577-b1430300-6993-11eb-939c-18620c00e2a1.png">

<hr/>

**Pulse** is a structured logging system built with SwiftUI. Record and inspect network requests and logs right from your iOS app using Pulse Console. Share and view logs in Pulse macOS app. Logs are recoded locally and never leave your device.

<br/>

![pulse-01-console](https://user-images.githubusercontent.com/1567433/107236825-129abe80-69f4-11eb-976a-4b5bc9dc383d.png)

<br/>

![pulse-02-inspector](https://user-images.githubusercontent.com/1567433/107172234-cf5c3380-6992-11eb-89a5-b77a78c09ec4.png)

<br/>

![pulse-03-share](https://user-images.githubusercontent.com/1567433/107172237-cf5c3380-6992-11eb-8459-83be62c16be0.png)

<br/>

![pulse-04-platforms](https://user-images.githubusercontent.com/1567433/107236017-475a4600-69f3-11eb-82d2-a0e11b760dd6.png)

<br/>

# About

`Pulse` is not a tool, it's a framework. It records events from `URLSession` or from frameworks that use it, such as `Alamofire`, and displays them using `PulseUI` views that you integrate directly into your app.

Pulse is distributed using Swift Package Manager as a binary framework. It is built using SwiftUI and includes no resources to ensure its tiny size. The thinned `.ipa` with Pulse included takes **<640 KB**. You can simply leave it in your app store builds. And because it's a binary framework, it doesn't increase your compile time.

<img src="https://user-images.githubusercontent.com/1567433/107464501-70cbbc80-6b2e-11eb-9404-2176287d85ac.png">

> Pulse **is not** a network debugging proxy tool like Proxyman, Charles, or Wireshark. It *won't* automatically intercept all network traffic coming from your app or device. 

The main advantage of Pulse it is integrated directly into your app and is always recording (when your code tells it to). Pulse console is available for everyone who has your test builds. You or your QA team can view the logs on the device and easily share them to attach to bug reports.

<br/>

# Installation

**Pulse** is available only for [**GitHub sponsors**](https://github.com/sponsors/kean) and will become free once it reaches enough sponsors. The access is provided manually, there might be a bit of a delay before you get access after sponsoring.

Please follow the [Installation Guide](https://github.com/kean/Pulse/blob/0.9.1/Docs/Installation.md).

<br/>

# Usage: Pulse

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

> For more information, please follow the [dedicated guide](https://github.com/kean/Pulse/blob/0.9.1/Docs/Logging.md).

#### Storage

All logged messages are stored persistently using Core Data, including metadata and other information. You get full access to all of the recorded messages at any time using `LoggerMessageStore`.

```swift
let message = try LoggerMessageStore.default.allMessage()

// NSPersistentStoreContainer
let container = logger.store.container
```

<br/>

# Usage: PulseUI

**PulseUI** framework provides all of the views that you saw on the screenshots.

Use `LoggerView` to display the root view with tabs. Use `ConsoleView`, `NetworkView`, and `PinView` to display individual tabs.

```swift
let view = LoggerView()
```

> PulseUI is built using SwiftUI. To use it in UIKit, wrap `ConsoleView` in a `UIHostingController`.

<br/>

# Pulse macOS App

**Upcoming**

<br/>

# Minimum Requirements

| Pulse          | Swift           | Xcode           | Platforms                                         |
|---------------|-----------------|-----------------|---------------------------------------------------|
| Pulse 0.9.0      | Swift 5.3       | Xcode 12.0      | iOS 13.0  (Upcoming conditional iOS 11+ and other platforms) | 
| Pulse 0.3      | Swift 5.2       | Xcode 11.3      | iOS 11.0 / watchOS 4.0 / macOS 10.13 / tvOS 11.0  |

# License

Pulse is available under the MIT license. See the LICENSE file for more info.

