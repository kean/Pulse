# Next Steps

Learn how to configure Pulse to best suit your app needs.

## Logger

### Configure Store

``LoggerStore`` is the primary way to configure how logs are stored. It uses a database to record logs in an efficient binary format and employes a number of space [optimizations techniques](https://kean.blog/post/pulse-2#space-savings), including fast [lzfse](https://developer.apple.com/documentation/compression/algorithm/lzfse) compression. The store automatically limits how much spaces it takes and also removed old logs.

```swift
LoggerStore.shared.configuration.sizeLimit = 512 * 1_000_000  
```

> important: Make sure to change it at the app launch before sending any logs.

### Exporting Logs

If you want to provide additional ways to share the logs recorded by the store, use ``LoggerStore/export(to:options:)``.

```swift
try await store.export(to: <#targetURL#>)
```

Export can be configured with a predicate to limit what gets exported:

```swift
var options = LoggerStore.ExportOptions(
    predicate: <#predicate#>,
    sessions: [<#sessionID#>]
)
```

> note: The exported store is in a Pulse document format (`.pulse` extension) 

### Accessing Logs

``LoggerStore`` uses Core Data and provides full access to its underlying entities, which you can use to access any previously stored logs, export them, or create custom views for your logs.

```swift
struct AnalyticsLogsView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \LoggerMessageEntity.createdAt, ascending: true)],
        predicate: NSPredicate(format: "label == %@", "analytics")
    ) var messages: FetchedResults<LoggerMessageEntity>

    var body: some View {
        List(messages, id: \.objectID) { message in
            <#view#>
        }
    }
}
``

> important: In the current schema, the alogger creates an associated ``LoggerMessageEntity`` entity for every ``NetworkTaskEntity``, but it will likely change in the future.  
