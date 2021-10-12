<br/>
<img alt="Pulse Logo" src="https://user-images.githubusercontent.com/1567433/109099548-47478f00-76f1-11eb-8ee7-652859514ab0.png">

**Pulse** is a powerful logging system for Apple Platforms. Native. Built with SwiftUI.

Record and inspect network requests and logs right from your iOS app using Pulse Console. Share and view logs in Pulse macOS app. Logs are recorded locally and never leave your device. Learn more at [**kean.blog/pulse**](https://kean.blog/pulse/home) 🔗.

<br/>
<br/>
<br/>
<br/>

![promo-4-2](https://user-images.githubusercontent.com/1567433/111088123-0d052c80-84fc-11eb-921c-af8de5c8032b.png)

<br/>

![promo-5](https://user-images.githubusercontent.com/1567433/113081170-2ff33a00-91a6-11eb-9e9d-5d1cd433f152.png)

<br/>

![promo-1](https://user-images.githubusercontent.com/1567433/107718771-ab576580-6ca4-11eb-83d9-ab1176f4e1c4.png)

<br/>

![promo-2](https://user-images.githubusercontent.com/1567433/107718772-ab576580-6ca4-11eb-83a1-fc510e57bab1.png)

<br/>

![promo-3](https://user-images.githubusercontent.com/1567433/107718773-abeffc00-6ca4-11eb-963a-04855e7304f4.png)

<br/>

<img width="2100" alt="08" src="https://user-images.githubusercontent.com/1567433/137036765-4aa2df39-8b4d-4df7-9697-0c66e5176f4e.png">

<br/>

![promo-6](https://user-images.githubusercontent.com/1567433/112777967-706d7f00-9011-11eb-82a8-12b3b29097cc.png)

<br/>

![promo-7](https://user-images.githubusercontent.com/1567433/112777285-d1945300-900f-11eb-8aaa-45d6ed392f3d.png)

<br/>

## About

`Pulse` is not a tool, it's a framework. It records events from `URLSession` or from frameworks that use it, such as `Alamofire`, and displays them using `PulseUI` views that you integrate directly into your app. This way Pulse console is available for everyone who has your test builds. You or your QA team can view the logs on the device and easily share them to attach to bug reports.

**Free**

Pulse is currently available for free. I thought it wouldn't make sense to try to make it paid as it's primarily a framework. But I hope that teams that use it would sponsor it. Think of it as "pay as much as you want."

**What Pulse is Not**

Pulse **is not** a network debugging proxy tool like Proxyman, Charles, or Wireshark. It *won't* automatically intercept all network traffic coming from your app or device. And to view logs in realtime, you need to use `PulseUI.framework` that you integrate into your app. The dedicated Pulse iOS and macOS also use `PulseUI.framework` and are there to view logs manually shared from other devices.


## Documentation

Pulse is easy to learn and use thanks to beautiful [**Pulse Docs**](https://kean.blog/pulse/home).

<a href="https://kean.blog/pulse/home">
<img src="https://user-images.githubusercontent.com/1567433/115163600-eea0cc80-a077-11eb-8b86-3113a657816f.png">
</a>

## Dependencies

- [ZIPFoundation](https://github.com/weichsel/ZIPFoundation/) for archiving Pulse documents (currently sponsoring it on GitHub). It's included directly in the binary.

## Minimum Requirements

**PulseUI** views are available only on indicated platforms, but the framework can be installed in the app targeting the **PulseCore** platforms – you just won't be able to use the views.

| Pulse          | Swift           | Xcode           | Platforms                                         |
|---------------|-----------------|-----------------|---------------------------------------------------|
| PulseCore 0.14.0      | Swift 5.3       | Xcode 12.0      | iOS 11.0  / watchOS 6.0 / tvOS 11.0 / macOS 11.0 |
| PulseUI 0.14.0      | Swift 5.3       | Xcode 12.0      | iOS 13.0 / watchOS 7.0 / tvOS 13.0 / macOS 11.0 |

## License

Pulse is available under the MIT license. See the LICENSE file for more info.

