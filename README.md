<br/>
<img width="2100" alt="01" src="https://user-images.githubusercontent.com/1567433/184552586-dd8cce3a-7ae1-494d-bbe9-41cfb1617c50.png">

**Pulse** is a powerful logging system for Apple Platforms. Native. Built with SwiftUI.

Record and inspect logs and `URLSession` network requests right from your iOS app using Pulse Console. Share and view logs in Pulse macOS app. Logs are recorded locally and never leave your device. Learn more at [**kean.blog/pulse**](https://kean.blog/pulse/home) 🔗.

> [Get](https://github.com/kean/Get), web API client built using async/await, has first-class Pulse integration.

## Sponsors 💖

[Support](https://github.com/sponsors/kean) Pulse on GitHub Sponsors.

<br/>
<br/>
<br/>

<img width="2100" alt="02" src="https://user-images.githubusercontent.com/1567433/184552587-60547a4e-eba9-4975-acb5-7ba53512a428.png">
<br/>
<img width="2100" alt="03" src="https://user-images.githubusercontent.com/1567433/184552588-2456b0de-7ac5-46cf-93e8-a74167993a94.png">
<br/>
<img width="2100" alt="04" src="https://user-images.githubusercontent.com/1567433/184552589-97bda910-e24e-4d16-8758-d44f9ccf7f4d.png">
<br/>
<img width="2100" alt="05" src="https://user-images.githubusercontent.com/1567433/184552590-a5b26199-3dcb-401f-b587-4d5688f9435e.png">
<br/>
<img width="2100" alt="06" src="https://user-images.githubusercontent.com/1567433/184552592-b7dedd25-18db-4017-9ced-9b311e9dc836.png">
<br/>
<img width="2100" alt="07" src="https://user-images.githubusercontent.com/1567433/184552593-aac8fa5a-7000-4ca8-80d8-f92c3d695002.png">
<br/>

## About

`Pulse` is not a tool, it's a framework. It records events from `URLSession` or from frameworks that use it, such as `Alamofire`, and displays them using `PulseUI` views that you integrate directly into your app. This way Pulse console is available for everyone who has your test builds. You or your QA team can view the logs on the device and easily share them to attach to bug reports.

**What Pulse is Not**

Pulse **is not** a network debugging proxy tool like Proxyman, Charles, or Wireshark. It *won't* automatically intercept all network traffic coming from your app or device. And to view logs in realtime, you need to use `PulseUI.framework` that you integrate into your app. The dedicated Pulse iOS and macOS also use `PulseUI.framework` and are there to view logs manually shared from other devices.


## Documentation

Pulse is easy to learn and use thanks to [**Pulse Docs**](https://kean.blog/pulse/home).

<a href="https://kean.blog/pulse/home">
<img src="https://user-images.githubusercontent.com/1567433/184552639-cf6765df-b5af-416b-95d3-0204e32df9d6.png">
</a>

## Pulse Pro

[**Pulse Pro**](https://kean.blog/pulse/guides/pulse-pro) is a professional open-source macOS app that allows you to view logs in real-time. The app is designed to be flexible, expansive, and precise while using all the familiar macOS patterns. It makes it easy to navigate large log files with table and text modes, filters, scroller markers, an all-new network inspector, JSON filters, and more.

## Minimum Requirements

| Pulse      | Swift     | Xcode       | Platforms                                     |
|------------|-----------|-------------|-----------------------------------------------|
| Pulse 2.0  | Swift 5.6 | Xcode 13.3  | iOS 13.0, watchOS 7.0, tvOS 13.0, macOS 11.0  |
| Pulse 1.0  | Swift 5.3 | Xcode 12.0  | iOS 11.0, watchOS 6.0, tvOS 11.0, macOS 11.0  |

## License

Pulse is available under the MIT license. See the LICENSE file for more info.
