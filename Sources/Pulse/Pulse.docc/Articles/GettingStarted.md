# Getting Started

Learn how to integrate Pulse.

## 1. Add Frameworks

**Option 1 (Recommended)**. Add package to your project using SwiftPM.

```
https://github.com/kean/Pulse
```

Add both **Pulse** and **PulseUI** libraries to your app.  

**Option 2**. Use precompiled binary frameworks from the [latest release](https://github.com/kean/Pulse/releases).

## 2. Integrate Pulse Framework

**Pulse** framework contains APIs for logging, capturing, and mocking network requests, as well as connecting to the Pulse Pro apps.

### 2.1. Capturing Network Requests

**Option 1 (Quick)**. If you are evaluating the framework, the quickest way to get started is with ``NetworkLogger/enableProxy(logger:)``.

```swift
#if DEBUG
NetworkLogger.enableProxy()
#endif
```

**Option 2 (Recommended)**. Use ``NetworkLogger/URLSession``, a thin wrapper on top of `URLSession`. 

```swift
let session: URLSessionProtocol
#if DEBUG
session = NetworkLogger.URLSession(configuration: .default)
#else
session = URLSession(configuration: .default)
#endif
```

> Tip: See <doc:NetworkLogging-Article> for more information about how to configure network logging if your app is not using `URLSession` directly, how to further customize it, how to capture and display decoding errors, and more. Pulse is modular and will accommodate almost any system.

### 2.2. Collecting Regular Messages

To store regular log messages, use [LoggerStore](https://kean-docs.github.io/pulse/documentation/pulse/loggerstore).

```swift
LoggerStore.shared.storeMessage(
    label: "auth",
    level: .debug,
    message: "Will login user",
    metadata: ["userId": .string("uid-1")]
)
```

> info: As an alternative to using `LoggerStore` directly, you can use Pulse as a SwiftLog backend using [PersistentLogHandler](https://kean-docs.github.io/pulseloghandler/documentation/pulseloghandler/persistentloghandler) struct from [PulseLogHandler](https://kean-docs.github.io/pulseloghandler/documentation/pulseloghandler) which is a [Swift package distributed separately](https://github.com/kean/PulseLogHandler).  This way you can have more than one logger at once.

Logs are stored persistently and the store automatically removes old messages and limits the overall size (configurable). It uses a number of space [optimizations techniques](https://kean.blog/post/pulse-2#space-savings), including fast [lzfse](https://developer.apple.com/documentation/compression/algorithm/lzfse) compression.

## 3. Integrate PulseUI Framework

To view logs and network requests from your app, use [PulseUI](https://kean-docs.github.io/pulseui/documentation/pulseui/) framework. The framework is centered around a single screen: `ConsoleView`. On iOS, you can push it into the existing navigation stack or present it modally.

```swift
NavigationLink(destination: ConsoleView()) {
    Text("Console")
}
```

> Note: There are some additional steps required for some platforms. For more information see the PulseUI [documentation](https://kean-docs.github.io/pulseui/documentation/pulseui/).

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
