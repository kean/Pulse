# ``PulseUI``

A set of components that you can integrate into your app to view the logs.

## Overview

The easiest way to integrate PulseUI is by using ``MainView`` (for SwiftUI) or ``MainViewController`` (for UIKit).

![A sloth hanging off a tree.](pulseui-main.png)

In addition to ``MainView``, you can also show individual tabs. For example, if you have an existing debug menu and 

## Custom Views

PulseUI gives you complete access to the underlying data and its model. You can easily create custom views into your log data by using affordances provided by SwiftUI:

```swift
struct AnalyticsLogsView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \LoggerMessageEntity.createdAt, ascending: true)],
        predicate: NSPredicate(format: "label == %@", "analyics")
    ) var messages: FetchedResults<LoggerMessageEntity>
    
    var body: some View {
        List(messages, id: \.objectID) { message in
            VStack(alignment: .leading) {
                Text(timeFormatter.string(from: message.createdAt))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Text(message.text)
                    .lineLimit(2)
            }
        }
    }
}

private let timeFormatter = DateFormatter(format: "HH:mm:ss.SSS")
```

## Topics

### Main View

- ``MainView``
- ``MainViewController``

### Individual Tabs

- ``ConsoleView``
- ``NetworkView``
- ``PinsView``
- ``InsightsView``
- ``SettingsView``
