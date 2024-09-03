# Getting Started

Learn how to integrate Pulse.

## 1. Add Frameworks

- **Option 1 (Recommended)**. Add package to your project using SwiftPM.

```
https://github.com/kean/Pulse
```

Add **Pulse** and **PulseUI** libraries to your app.

- **Option 2**. Use precompiled binary frameworks from the [latest release](https://github.com/kean/Pulse/releases).

## 2. Integrate Pulse Framework

**Pulse** framework contains APIs for logging, capturing, and mocking network requests, as well as connecting to the Pulse Pro apps.

### 2.1. Capture Network Requests

- **Option 1 (Recommended)**. Use ``URLSessionProxy``, a thin wrapper on top of `URLSession`. 

```swift
import Pulse

#if DEBUG
let session: URLSessionProtocol = URLSessionProxy(configuration: .default)
#else
let session: URLSessionProtocol = URLSession(configuration: .default)
#endif
```

> tip: See <doc:NetworkLogging-Article> for more information about how to configure network logging if your app does not use `URLSession` directly, how to further customize it, how to capture and display decoding errors, and more. Pulse is modular and will accommodate almost any system.

- **Option 2 (Quickest)**. If you are evaluating the framework, the quickest way to get started is with a proxy from the **PulseProxy** module.

```swift
import PulseProxy

#if DEBUG
NetworkLogger.enableProxy()
#endif
```

> important: **PulseProxy** uses swizzling and private APIs and it is not recommended that you include it in the production builds of your app.

### 2.2. Collect Logs

To store regular log messages, use [LoggerStore](https://kean-docs.github.io/pulse/documentation/pulse/loggerstore).

```swift
LoggerStore.shared.storeMessage(
    label: "auth",
    level: .debug,
    message: "Will login user",
    metadata: ["userId": .string("uid-1")]
)
```

> tip: Alternatively, you can use it as a SwiftLog backend using [PersistentLogHandler](https://kean-docs.github.io/pulseloghandler/documentation/pulseloghandler/persistentloghandler) from a [PulseLogHandler](https://github.com/kean/PulseLogHandler) package.

## 3. Integrate PulseUI Framework

[**PulseUI**](https://kean-docs.github.io/pulseui/documentation/pulseui/) allows you to view logs and network requests directly from your app. The framework is centered around a single screen: `ConsoleView`. On iOS, you can push it into the existing navigation stack or present it modally.

```swift
import PulseUI

NavigationLink(destination: ConsoleView()) {
    Text("Console")
}
```

> tip: For more information, see the PulseUI [documentation](https://kean-docs.github.io/pulseui/documentation/pulseui/).

![Pulse Console](pulse-console.png)

## 4. Get Pulse Apps

Pulse also provides separate indispensable [macOS and iOS apps](https://pulselogger.com) that you can use to view logs collected by the Pulse SDK and even debug your apps in real-time with features like response mocking. The app are [available on the App Store](https://apps.apple.com/us/app/pulse-network-logger/id6661031747).

The apps require two more simple configuration steps.

### 4.1. Update Info.plist

Add the following to your app's plist file:

```swift
<key>NSLocalNetworkUsageDescription</key>
<string>Network usage required only for development purposes</string>
<key>NSBonjourServices</key>
<array>
  <string>_pulse._tcp</string>
</array>
```

> important: Pulse will **not show** any prompts unless you enable remote logging from the Pulse settings screen.

### 4.2. Enable Remote Logging

Open the Pulse console from the app, go to Settings, enable "Remote Logging", and select a device running Pulse Pro to connect to.

![Enabling remote logging](remote-logging.png)

Once the connection is established, open the Pulse app on your Mac and select the device in the sidebar. The next time you launch the app, the connection will happen automatically.

![Pulse Pro](pulse-pro.png)

## Next Steps

Learn how to configure Pulse to best suit your app needs in <doc:NextSteps> and explore additional networking debugging techniques in <doc:NetworkLogging-Article>. 
