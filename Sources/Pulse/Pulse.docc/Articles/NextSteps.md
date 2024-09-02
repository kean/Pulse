# Next Steps

Learn how to configure Pulse to best suit your app needs.

## Logger

### Configure Store

``LoggerStore`` is the primary way to configure how logs are stored. It uses a database to record logs in an efficient binary format and employes a number of space [optimizations techniques](https://kean.blog/post/pulse-2#space-savings), including fast [lzfse](https://developer.apple.com/documentation/compression/algorithm/lzfse) compression. The store automatically limits how much spaces it takes and also removed old logs.

You can configure the logger be replacing the default store.

```swift
var configuration = LoggerStore.Configuration()
configuration.sizeLimit = 512 * 1_000_000

LoggerStore.shared = try LoggerStore(storeURL: <#storeURL#>, configuration: configration)  
```
