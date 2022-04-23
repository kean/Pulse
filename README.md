<br/>
<img alt="Pulse Logo" src="https://user-images.githubusercontent.com/1567433/164947152-9760dd7b-c883-4059-b5dc-e66df031f0c9.png">

**Pulse** is a powerful logging system for Apple Platforms. Native. Built with SwiftUI.

Record and inspect logs and `URLSession` network requests right from your iOS app using Pulse Console. Share and view logs in Pulse macOS app. Logs are recorded locally and never leave your device. Learn more at [**kean.blog/pulse**](https://kean.blog/pulse/home) 🔗.

> [Get](https://github.com/kean/Get), web API client built using async/await, has first-class Pulse integration.

<br/>
<br/>
<br/>
<br/>

<img width="2100" alt="02" src="https://user-images.githubusercontent.com/1567433/164947161-3e9a5343-9c4c-4d03-a4f0-24fb0a71b94d.png">
<br/>
<img width="2100" alt="03" src="https://user-images.githubusercontent.com/1567433/164947162-f7ea32f9-d20b-493c-9edd-279620416872.png">
<br/>
<img width="2100" alt="04" src="https://user-images.githubusercontent.com/1567433/164947163-dfa2be99-2267-4e5c-9723-48e88d4386bd.png">
<br/>
<img width="2100" alt="05" src="https://user-images.githubusercontent.com/1567433/164947165-2adc3174-0d88-4e07-8428-d57a4cd35ad0.png">
<br/>
<img width="2100" alt="06" src="https://user-images.githubusercontent.com/1567433/164947167-6f503ae1-5c40-4fc3-accb-289e160352aa.png">
<br/>
<img width="2100" alt="07" src="https://user-images.githubusercontent.com/1567433/164947168-5e163b13-42b0-40f3-abc3-47197058e11a.png">
<br/>

## Pulse Pro

[**Pulse Pro**](https://kean.blog/pulse/guides/pulse-pro) is an advanced macOS app providing ultimate logging experience. [Download](https://github.com/kean/Pulse/releases/download/0.20.0/PulsePro-demo.zip) a trial version.

<img width="2100" alt="08" src="https://user-images.githubusercontent.com/1567433/141652571-789aae3e-10b9-461f-bd51-a4a44110140f.png">

<br/>

## About

`Pulse` is not a tool, it's a framework. It records events from `URLSession` or from frameworks that use it, such as `Alamofire`, and displays them using `PulseUI` views that you integrate directly into your app. This way Pulse console is available for everyone who has your test builds. You or your QA team can view the logs on the device and easily share them to attach to bug reports.

**What Pulse is Not**

Pulse **is not** a network debugging proxy tool like Proxyman, Charles, or Wireshark. It *won't* automatically intercept all network traffic coming from your app or device. And to view logs in realtime, you need to use `PulseUI.framework` that you integrate into your app. The dedicated Pulse iOS and macOS also use `PulseUI.framework` and are there to view logs manually shared from other devices.


## Documentation

Pulse is easy to learn and use thanks to [**Pulse Docs**](https://kean.blog/pulse/home).

<a href="https://kean.blog/pulse/home">
<img src="https://user-images.githubusercontent.com/1567433/115163600-eea0cc80-a077-11eb-8b86-3113a657816f.png">
</a>

## Dependencies

- [ZIPFoundation](https://github.com/weichsel/ZIPFoundation/) for archiving Pulse documents. It's included directly in the binary.

## Minimum Requirements

**PulseUI** views are available only on indicated platforms, but the framework can be installed in the app targeting the **PulseCore** platforms – you just won't be able to use the views.

| Pulse          | Swift           | Xcode           | Platforms                                         |
|---------------|-----------------|-----------------|---------------------------------------------------|
| PulseCore 0.14.0      | Swift 5.3       | Xcode 12.0      | iOS 11.0  / watchOS 6.0 / tvOS 11.0 / macOS 11.0 |
| PulseUI 0.14.0      | Swift 5.3       | Xcode 12.0      | iOS 13.0 / watchOS 7.0 / tvOS 13.0 / macOS 11.0 |

## License

Pulse is available under the MIT license. See the LICENSE file for more info.

