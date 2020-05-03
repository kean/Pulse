
# Pulse

Structured Logging System

<br/>

## Getting Started

Pulse allows you to log messages and store them persistently.

```swift
/// Logs the message in the console (if enabled) and saves it persistently.
///
public func log(level: Logger.Level = .debug,
                system: Logger.System = .default,
                category: Logger.Category = .default,
                _ text: @autoclosure () -> String)
```

The messages are stored in a structured manner using Core Data. You get full access to all of the recoreded messages at any time either using `Logger.Store` or using `NSPersistentStoreCoordinator` directly.

<br/>

## PulseUI

To view messages, use `PulseUI` package. The package is only available for [GitHub sponsors](https://github.com/sponsors/kean).

<br/>

### iOS Console

Build a console right into your iOS apps.

<img width="320" alt="Screen Shot 2020-05-02 at 21 15 32" src="https://user-images.githubusercontent.com/1567433/80896282-d85cfd80-8cba-11ea-83f7-323cdf844bc9.png"> <img width="320" alt="Screen Shot 2020-05-02 at 21 16 00" src="https://user-images.githubusercontent.com/1567433/80896284-d98e2a80-8cba-11ea-8bd0-8c5500483766.png">

<br/>

### macOS Console

Share your Pulse database and view it on your Mac. Use advanced search to filter your messages.

<img width="800" alt="Screen Shot 2020-05-02 at 21 11 01" src="https://user-images.githubusercontent.com/1567433/80896328-22de7a00-8cbb-11ea-886e-8e29c4d9f7f0.png">


