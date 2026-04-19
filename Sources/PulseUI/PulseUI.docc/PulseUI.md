# ``PulseUI``

A set of components that you can integrate into your app to view the logs.

## Overview

### SwiftUI

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

### UIKit

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

## Customization

### Settings

Pulse is highly customizable and provides a massive number of settings in ``UserSettings``, including the options for customizing the look of the cells in the list, and more.

### Per-Task Customization

For per-task behaviour — different display settings, custom SwiftUI views inside the task cell or network inspector, extra context-menu items, or redacting sensitive strings before they are rendered — conform to ``ConsoleDelegate`` and pass the delegate to ``ConsoleView``:

```swift
import Pulse
import PulseUI
import SwiftUI

final class AppConsoleDelegate: ConsoleDelegate {
    // Decode protobuf responses using the app's own generated types
    func console(responseBodyViewFor task: NetworkTaskEntity) -> AnyView? {
        guard task.response?.contentType?.isProtobuf == true,
              let data = task.responseBody?.data,
              let message = try? MyProtobufMessage(serializedBytes: data) else {
            return nil
        }
        let text = NSAttributedString(string: message.textFormatString())
        let viewModel = RichTextViewModel(string: text, contentType: nil)
        return AnyView(RichTextView(viewModel: viewModel))
    }

    // Mask auth tokens before they are shown anywhere in the UI
    func console(redact value: String, field: ConsoleRedactionField, for task: NetworkTaskEntity) -> String {
        switch field {
        case .requestHeader("Authorization"): "Bearer ***"
        default: value
        }
    }

    // Inject an app-specific "Replay" item into each task's context menu
    func console(contextMenuFor task: NetworkTaskEntity) -> AnyView? {
        AnyView(Button("Replay") { replay(task) })
    }
}

ConsoleView(delegate: AppConsoleDelegate())
```

All ``ConsoleDelegate`` methods have default implementations, so you only need to implement the hooks you care about. The delegate is consulted from both the list and the network inspector, so customizations apply everywhere the task is shown.

Available hooks:

- ``ConsoleDelegate/console(listDisplayOptionsFor:)`` — return per-task ``ConsoleListDisplaySettings`` (the default uses ``UserSettings``)
- ``ConsoleDelegate/console(contentViewFor:)`` — replace the cell's main content area (method + URL). Supersedes ``ConsoleListDisplaySettings/ContentSettings`` for that task
- ``ConsoleDelegate/console(responseBodyViewFor:)`` — replace the built-in response body viewer. Useful for protobuf, gRPC, or any format the default `FileViewer` doesn't understand
- ``ConsoleDelegate/console(inspectorViewFor:)`` — inject a custom SwiftUI section into the network inspector (e.g. decoded GraphQL variables, parsed protobuf)
- ``ConsoleDelegate/console(contextMenuFor:)`` — add app-specific items to the task's context menu and to the network inspector's "More" menu
- ``ConsoleDelegate/console(redact:field:for:)`` — redact URLs, hosts, header values, task descriptions, and caller-supplied strings. The ``ConsoleRedactionField`` argument identifies which field is about to be rendered

To build custom response-body views that share the look and feel of the built-in viewer, use ``RichTextView`` and ``RichTextViewModel`` — both are public. You get search, line numbers, link detection, and share for free.

For matching protobuf and gRPC content types when deciding whether to handle a response, use ``NetworkLogger/ContentType/isProtobuf``.

### Injecting Custom Cell Content Without a Delegate

If you just want to show a caller-supplied string in place of the method + URL (for example, a GraphQL operation name) or in a header/footer field, you can skip the delegate entirely and set these directly on ``ConsoleListDisplaySettings``:

- ``ConsoleListDisplaySettings/ContentSettings/customText`` — render a literal string in the cell's content area
- ``ConsoleListDisplaySettings/TaskField/url(components:)`` — render the full URL, or specific ``ConsoleListDisplaySettings/URLComponent``s, in a field
- ``ConsoleListDisplaySettings/TaskField/custom(_:)`` — render a literal string in a field

### Custom Views

PulseUI gives you complete access to the underlying data and its model. You can easily create custom views into your log data by using affordances provided by SwiftUI:

```swift
struct AnalyticsLogsView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \LoggerMessageEntity.createdAt, ascending: true)],
        predicate: NSPredicate(format: "label == %@", "analytics")
    ) var messages: FetchedResults<LoggerMessageEntity>
    
    var body: some View {
        List(messages, id: \.objectID) { message in
            NavigationLink {
                Text("TODO: your details view here")
            } label: {
                VStack(alignment: .leading) {
                    HStack {
                        Text(timeFormatter.string(from: message.createdAt))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Spacer()
                        ListDisclosureIndicator()
                    }
                    Text(message.text)
                        .lineLimit(2)
                }
            }
        }
        .listStyle(.plain)
    }
}

private let timeFormatter = DateFormatter(format: "HH:mm:ss.SSS")
```

> tip: For a complete example, see the [Integrations](https://github.com/kean/Pulse/tree/main/Demo/Integrations) demo.

## PulseUI on watchOS

## Topics

### Main Views

- ``ConsoleView``
- ``SettingsView``
- ``UserSettings``

### Per-Task Customization

- ``ConsoleDelegate``
- ``ConsoleRedactionField``
- ``ConsoleListDisplaySettings``

### Custom Views

- ``RichTextView``
- ``RichTextViewModel``

### Deprecated

- ``MainViewController``
