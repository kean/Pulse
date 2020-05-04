![pulse](https://user-images.githubusercontent.com/1567433/80919453-f0269700-8d37-11ea-8099-c1f91161d771.jpg)

<p align="left">
<img src="https://img.shields.io/badge/platforms-iOS%2C%20macOS%2C%20watchOS%2C%20tvOS-lightgrey.svg">
<!-- <a href="https://travis-ci.org/kean/Pulse"><img src="https://img.shields.io/travis/kean/Pulse/master.svg"></a> -->
</p>

**Pulse** is a logging system with structured persistent storage.

**PulseUI** allows you to quickly preview logs in your iOS or tvOS apps. Share logs, and use Pulse macOS app to search and filter them. **PulseUI** is available for [**GitHub sponsors**](https://github.com/sponsors/kean).

<br/>

# Usage

Use `log()` function to send logs.

```swift
log("Your message")
log(level: .fatal, system: .auth, "Configuration is missing")
```

```swift
/// Logs the message in the console (if enabled) and saves it persistently.
///
/// - note: Logger automatically captures stack traces for .fatal logs.
///
public func log(level: Logger.Level = .debug,
                system: Logger.System = .default,
                category: Logger.Category = .default,
                _ text: @autoclosure () -> String)
```

All of the logged messages are stored persistently using Core Data. You get full access to all of the recorded messages at any time using `Logger.Store`.

```swift
let message = try logger.store.allMessage()

// NSPersistentStoreContainer
let container = logger.store.container
```

<br/>

# PulseUI

**PulseUI** allows you to quickly preview logs in your iOS or tvOS apps. Share logs, and use Pulse macOS app to search and filter them. **PulseUI** is available for [**GitHub sponsors**](https://github.com/sponsors/kean).

<br/>

### iOS Console

Build a console right into your iOS apps.

<img width="320" alt="Screen Shot 2020-05-03 at 09 58 50" src="https://user-images.githubusercontent.com/1567433/80921120-54e6ef00-8d42-11ea-918d-8d27ea54ae98.png"> <img width="320" alt="Screen Shot 2020-05-04 at 10 43 28" src="https://user-images.githubusercontent.com/1567433/80979399-49083500-8df5-11ea-8313-54841b86777c.png">

<br/>

### macOS App

Share your Pulse database and view it on your Mac. Use advanced search to filter your messages.

<img width="800" alt="Screen Shot 2020-05-02 at 21 11 01" src="https://user-images.githubusercontent.com/1567433/80921060-cc684e80-8d41-11ea-8ec3-4bb752d04a33.png">

# Minimum Requirements

| Nuke          | Swift           | Xcode           | Platforms                                         |
|---------------|-----------------|-----------------|---------------------------------------------------|
| Pulse 0.1      | Swift 5.2       | Xcode 11.3      | iOS 13.0 / watchOS 6.0 / macOS 10.15 / tvOS 13.0  |

# License

Pulse is available under the MIT license. See the LICENSE file for more info.

