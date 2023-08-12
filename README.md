<img width="2100" alt="promo-main" src="https://github.com/kean/Pulse/assets/1567433/d8d588db-e165-4beb-9aec-c4a93e59ba29">

<br/>
<br/>

[**Pulse**](https://kean.blog/pulse/home) is a powerful logging system for Apple Platforms. Native. Built with SwiftUI.

Record and inspect logs and `URLSession` network requests right from your iOS app. Share logs and view them in [Pulse Pro](https://pulselogger.com) or use remote logging to see them in real time. Logs are stored locally and never leave your devices.

## About

`Pulse` is not just a tool, it's a framework. It records events from `URLSession` or from frameworks that use it, such as [Alamofire](https://github.com/Alamofire/Alamofire) or [Get](https://github.com/kean/Get), and displays them using `PulseUI` views that you integrate directly into your app. This way Pulse console is available for everyone who has your test builds. You or your QA team can view the logs on the device and easily share them to attach to bug reports.

> Pulse is **not** a network proxy. If you need one, check out [**Proxyman**](https://proxyman.io).

## Getting Started

The best way to start using Pulse is with the [**Getting Started**](https://kean-docs.github.io/pulse/documentation/pulse/gettingstarted) guide. There are many ways to use it and to learn more, see the dedicated docs: 

- [**Pulse Docs**](https://kean-docs.github.io/pulse/documentation/pulse/) describe how to integrate the main framework and enable logging
- [**PulseUI Docs**](https://kean-docs.github.io/pulseui/documentation/pulseui/) contains information about adding the debug menu and console into your app
- [**PulseLogHandler Docs**](https://kean-docs.github.io/pulseloghandler/documentation/pulseloghandler/) describe how to use Pulse as [SwiftLog](https://github.com/apple/swift-log) backend

<a href="https://kean.blog/pulse/home">
<img src="https://user-images.githubusercontent.com/1567433/184552639-cf6765df-b5af-416b-95d3-0204e32df9d6.png">
</a>

## Pulse Pro

[**Pulse Pro**](https://pulselogger.com) is a professional macOS app that allows you to view logs in real time. The app is designed to be flexible, expansive, and precise while using all the familiar macOS patterns. It makes it easy to navigate large log files with table and text modes, filters, an all-new network inspector, JSON filters, and more.

## Minimum Requirements

| Pulse      | Swift     | Xcode       | Platforms                                    |
|------------|-----------|-------------|----------------------------------------------|
| Pulse 4.0  | Swift 5.7 | Xcode 14.1  | iOS 14.0, tvOS 15.0, watchOS 8.0, macOS 12.0 |
| Pulse 3.0  | Swift 5.7 | Xcode 14.1  | iOS 14.0, tvOS 14.0, watchOS 8.0, macOS 12.0 |

## License

Pulse is available under the MIT license. See the LICENSE file for more info.
