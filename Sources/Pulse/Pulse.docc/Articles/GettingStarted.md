# Getting Started

Learn how to integrate Pulse.

## Overview

Pulse is a framework that provides complete access to the underlying data, and there are many ways to use it. This guide describes the basic integration steps.

## 1. Add Pulse and PulseUI Frameworks to Your App

There are two main installation options:

- Add Pulse Swift package to your project using SPM

```
https://github.com/kean/Pulse
```

- Use precompiled binary frameworks from the [latest release](https://github.com/kean/Pulse/releases)

> info: If you'd like to create binary frameworks using a specific Xcode version, consider using [swift-create-xcframework](https://github.com/marketplace/actions/swift-create-xcframework).

## 2. Integrate Pulse Framework

To start collecting logs, use [Pulse](https://kean-docs.github.io/pulse/documentation/pulse/) framework.

### 2.1. Collecting Regular Messages

To store regular log messages, use [LoggerStore](https://kean-docs.github.io/pulse/documentation/pulse/loggerstore).

```swift
LoggerStore.shared.storeMessage(
    label: "auth",
    level: .debug,
    message: "Will login user",
    metadata: ["userId": .string("uid-1")]
)
```

> info: As an alternative to using `LoggerStore` directly, you can use Pulse as a SwiftLog backend using [PersistentLogHandler](https://kean-docs.github.io/pulseloghandler/documentation/pulseloghandler/persistentloghandler) struct from [PulseLogHandler](https://kean-docs.github.io/pulseloghandler/documentation/pulseloghandler) which is a Swift package distributed separately.  This way you can have more than one logger at once.

### 2.2. Collecting Network Requests

The recommended option is to use ``URLSessionProxyDelegate`` which sits between [`URLSession`](https://developer.apple.com/documentation/foundation/urlsession) and your actual [`URLSessionDelegate`](https://developer.apple.com/documentation/foundation/urlsessiondelegate).

You can enable ``URLSessionProxyDelegate`` for all `URLSession` instances created by the app by using ``URLSessionProxyDelegate/enableAutomaticRegistration(logger:)``.

```swift
// Call it anywhere in your code before instantiating a `URLSession`
URLSessionProxyDelegate.enableAutomaticRegistration()

// Instantiate `URLSession` as usual
let session = URLSession(
    configuration: .default,
    delegate: YourURLSessionDelegate(),
    delegateQueue: nil
)
```

> Important: This option works only with delegate-based sessions, which includes [Alamofire](https://github.com/Alamofire/Alamofire) and [Get](https://github.com/kean/Get). It will **not** work with `URLSession.shared`. For other options, see the dedicated [guide](https://kean-docs.github.io/pulse/documentation/pulse/networklogging-article).

Logs are stored persistently and the store automatically removes old messages and limits the overall size (configurable). It uses a number of space [optimizations techniques](https://kean.blog/post/pulse-2#space-savings), including fast [lzfse](https://developer.apple.com/documentation/compression/algorithm/lzfse) compression.

> Tip: To get the most out of the network logger, follow the <doc:NetworkLogging-Article> guide. For example, starting with Pulse 2.0, you can record and view [decoding errors](https://kean.blog/post/pulse-2#decoding-errors) which makes it much easier to see why decoding is failing.

## 3. Integrate PulseUI Framework

To view logs and network requests from your app, use [PulseUI](https://kean-docs.github.io/pulseui/documentation/pulseui/) framework. The framework is centered around a single screen: `ConsoleView`. On iOS, you can push it into the existing navigation stack or present manually.

## 4. Configure Remote Logging with Pulse Pro

In addition to the frameworks and the on-device view, Pulse also provides a separate professional macOS app called [Pulse Pro](https://kean.blog/pulse/pro) that you can use for viewing the previously shared logs or even viewing the logs from the device remotely in real-time.

To start using remote logging, there are a couple of extra setup steps:

### 4.1. Configure the App

Add the following to the app's plist file to allow it to use local networking:

```swift
<key>NSLocalNetworkUsageDescription</key>
<string>Network usage required for debugging purposes </string>
<key>NSBonjourServices</key>
<array>
  <string>_pulse._tcp</string>
</array>
```

> Note: There will be no user prompts unless you enable remote logging from settings.

### 4.2. Enable Remote Logging

Open the Pulse console from the app, go to Settings, enable "Remote Logging", and select a device running Pulse Pro to connect to.

![Enabling remote logging](remote-logging.png)

Once the connection is established, open Pulse Pro and select the device in the sidebar. The next time you launch the app, the connection will happen automatically.
