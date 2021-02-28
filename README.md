<br/>
<img alt="Pulse Logo" src="https://user-images.githubusercontent.com/1567433/109099548-47478f00-76f1-11eb-8ee7-652859514ab0.png">

<hr/>

**Pulse** is a powerful logging system. Record and inspect network requests and logs right from your iOS app using Pulse Console. Share and view logs in Pulse macOS app. Logs are recorded locally and never leave your device.

<a href="https://testflight.apple.com/join/B2p3vcwl">
<img height=60 src="https://user-images.githubusercontent.com/1567433/108601031-66989200-7368-11eb-92dd-f5da70a3c4f6.png">
</a>

<br/>
<br/>
<br/>
<br/>

![promo-4](https://user-images.githubusercontent.com/1567433/108644405-c718f380-747c-11eb-87f3-1d12f418c00a.png)

<br/>

![promo-5](https://user-images.githubusercontent.com/1567433/108644060-60dfa100-747b-11eb-8b14-bf94d609c4e5.png)

<br/>

![promo-1](https://user-images.githubusercontent.com/1567433/107718771-ab576580-6ca4-11eb-83d9-ab1176f4e1c4.png)

<br/>

![promo-2](https://user-images.githubusercontent.com/1567433/107718772-ab576580-6ca4-11eb-83a1-fc510e57bab1.png)

<br/>

![promo-3](https://user-images.githubusercontent.com/1567433/107718773-abeffc00-6ca4-11eb-963a-04855e7304f4.png)

<br/>

# About

`Pulse` is not a tool, it's a framework. It records events from `URLSession` or from frameworks that use it, such as `Alamofire`, and displays them using `PulseUI` views that you integrate directly into your app.

> Pulse **is not** a network debugging proxy tool like Proxyman, Charles, or Wireshark. It *won't* automatically intercept all network traffic coming from your app or device. 

Pulse is integrated directly into your app and is always recording (when your code tells it to). Pulse console is available for everyone who has your test builds. You or your QA team can view the logs on the device and easily share them to attach to bug reports. That's powerful.

<br/>

# Installation

**Pulse** is available only for [**GitHub sponsors**](https://github.com/sponsors/kean). Once the number of sponsors reaches a certain level, the project will become available to everyone.

> The access to the private project manifest is provided manually, there might be a bit of a delay before you get access after sponsoring.

Pulse is distributed using Swift Package Manager as a binary framework. It is built using SwiftUI and includes no resources to ensure its tiny size. The thinned `.ipa` with Pulse included takes **<640 KB**. You can simply leave it in your app store builds. And because it's a binary framework, it doesn't increase your compile time.

<img src="https://user-images.githubusercontent.com/1567433/107464501-70cbbc80-6b2e-11eb-9404-2176287d85ac.png">

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
let messages = try LoggerMessageStore.default.allMessages()

// NSPersistentContainer
let container = LoggerMessageStore.default.container
```

<br/>

# Usage: PulseUI

**PulseUI** framework provides all of the views that you saw on the screenshots.

Use `MainView` (or `MainViewController` for convenient UIKit integration) to display the root view with tabs. Use `ConsoleView`, `NetworkView`, and `PinView` to display individual tabs.

```swift
let view = MainView()
```

Pulse views are built using SwiftUI and require iOS 13. But even if your app requires iOS 11, no need to worry. Pulse can still be easily integrated into your project. The framework itself requires iOS 11 and Pulse views can be easily added conditionally on iOS 13+. To show Pulse from UIKit, use convenience `MainViewController` class.

<br/>

# Pulse macOS App

Pulse macOS Alpha is now available as early access. Requires Big Sur.

> Demo store is attached to the latest release.

<br/>

# Status

|  Project         | Status          |
|---------------|-----------------|
| Pulse    | Beta       |
| PulseUI (iOS framework)      | Beta       |
| Pulse (macOS app)      | Alpha |
| tvOS, watchOS support      | Upcoming |

# Minimum Requirements

| Pulse          | Swift           | Xcode           | Platforms                                         |
|---------------|-----------------|-----------------|---------------------------------------------------|
| Pulse 0.9.2      | Swift 5.3       | Xcode 12.0      | iOS 11.0 (views requires iOS 13) | 
| Pulse 0.9.0      | Swift 5.3       | Xcode 12.0      | iOS 13.0  (Upcoming conditional iOS 11+ and other platforms) | 
| Pulse 0.3      | Swift 5.2       | Xcode 11.3      | iOS 11.0 / watchOS 4.0 / macOS 10.13 / tvOS 11.0  |

# License

Pulse is available under the MIT license. See the LICENSE file for more info.

