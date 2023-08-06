# ``PulseUI``

A set of components that you can integrate into your app to view the logs.

## Overview

The easiest way to integrate PulseUI is by using ``ConsoleView``.

```swift
// Present modally
Text("Console").sheet(isPresented: $isConsolePresented) {
    NavigationView {
        ConsoleView()
    }
}
```

```swift
// Push into the navigation stack.
NavigationLink(destination: ConsoleView()) {
    Text("Console")
}
```

> tip: If you use Pulse to log only network requests, and not text messages, use `ConsoleView(mode: .network)` to show a view specialized to only display network requests.

## UIKit

To present the console from `UIKit`, use `UIHostingController`:

```swift
let view = NavigationView { 
    ConsoleView()
}
present(UIHostingController(rootView: view), animated: true)
```

If you are using appearance to change the navigation bar `isTranslucent` property to `false`, make sure to set `extendedLayoutIncludesOpaqueBars` to `true`:

```swift
let vc = UIHostingController(rootView: ConsoleView())
vc.extendedLayoutIncludesOpaqueBars = true
let nav = UINavigationController(rootViewController: vc)
nav.navigationBar.prefersLargeTitles = true
present(nav, animated: true)
```

## Custom Views

PulseUI gives you complete access to the underlying data and its model. You can easily create custom views into your log data by using affordances provided by SwiftUI:

```swift
struct AnalyticsLogsView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \LoggerMessageEntity.createdAt, ascending: true)],
        predicate: NSPredicate(format: "label == %@", "analytics")
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

## PulseUI on watchOS

## Topics

### Main Views

- ``ConsoleView``
- ``SettingsView``
- ``UserSettings``

### Deprecated

- ``MainViewController``
