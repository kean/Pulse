# Pulse 4.x

## Pulse 4.0.4

*Nov 5, 2023*

- Fix [#217](https://github.com/kean/Pulse/issues/217): arithmetic overflow when the the number of deduplicated data links exceed the size limit 

## Pulse 4.0.3

*Aug 27, 2023*

- Improve performance of recording network tasks
- Improve `NetworkLogger` performance
- Fix an issue with requests from the previous app run being displayed as pending
- Add a "Mock" badge when exporting the store using one of the text formats

## Pulse 4.0.2

*Aug 19, 2023*

- Fix an issue with list not displaying older messages (iOS)
- Update JSON color theme (watchOS)
- The console now fully adopts your app's tint color (iOS, watchOS, macOS, tvOS)
- Move "Store Info" button to Settings (iOS)
- Network inspector will now show a "current" request by default and remember your selection (see `UserSettings.shared.isShowingCurrentRequest`)

## Pulse 4.0.1

*Aug 7, 2023*

- Fix [#211](https://github.com/kean/Pulse/issues/211): crash when opening network details on iOS
- Fix [#208](https://github.com/kean/Pulse/issues/208): searching removes the backgroundColor of decoding error highlighted text – [#210](https://github.com/kean/Pulse/pull/210) by @Ahattalla 

## Pulse 4.0

*Aug 6, 2023*

### Requirements

- Set the minimum platform requirements to iOS 14.0, tvOS 15.0, watchOS 8.0, macOS 12.0. `ConsoleView` is available on iOS 15, but you can still integrate the framework in apps that support earlier iOS versions.
- Increase the minimum supported Xcode version to Xcode 14.1
- Add Xcode 15 support 
- Add iOS 17, tvOS 17, watchOS 10, macOS 14 support
- Remove APIs deprecated in Pulse 3.x

### Remote Logging

- Add support for the new Pulse for Mac app coming to App Store this month. You can try it now by [joining](https://testflight.apple.com/join/1jcanE3q) the public beta. More information on the app will be available soon.
- [Redesign](https://github-production-user-asset-6210df.s3.amazonaws.com/1567433/244578507-99e03a6a-c830-4174-add5-9b68d3c96c47.png) the remote settings screen making it easier to connect to Pulse for Mac. The new screen has improved error handling and shows instructions on configuring the app to use it. It now also remembers all recently connected devices, so if you use more than one Mac for development, it will remember both.
- Add support for password-protected and encrypted connections to Pulse for Mac
- Add a way to "Forget the Device" without disabling the remote logger
- Fix synchronization issues in the remote logger
- Add "Show on Mac" feature that allows you to quickly open a log details page selected in the iOS app on a Mac without even starting the remote logging (iOS only)
- Add missing NSBonjourServices plist setting to the demo project that was preventing the demo app from connecting on a local network

### Features

- [iOS] The "network" tab is now the first item in the menu and is selected by default. The selection is now also sticky.
- [iOS] Add a way to display custom HTTP headers directly in the Console - [#196](https://github.com/kean/Pulse/pull/196) by @tahirmt
- [iOS] Add quick filters by `host`, and `url` to the network task context menus
- [iOS] When you import store from watchOS, it now shows an "Open Store" button directly in the Console
- Add a public `UserSettings` class that allows you to programmatically change some of the console settings or pass them using launch arguments 
- [watchOS] Update the design for watchOS 10
- [watchOS] Fix [#201](https://github.com/kean/Pulse/issues/201) by removing the code that sets WCSession delegate from the framework. It's now up to the user to forward the required delegate calls to the framework: only two are needed. Please see the included demo projects for an example.
- [watchOS] Fix [#200](https://github.com/kean/Pulse/issues/200) by disabling the Remote Logging toggle when running on a physical watchOS device.
- [watchOS] Add a "Share Store" button to the Settings screen that uses the new native [ShareLink](https://developer.apple.com/documentation/SwiftUI/ShareLink) API to add more ways to share logs from your logs: email, messages, and more.
- [watchOS] Add demo with paired iOS and watchOS apps
- [macOS] Move some network filters to Pulse for Mac
- [macOS] Move inspectors to the navigation bar on macOS
- [macOS] Add "Now" mode

# Pulse 3.x

## Pulse 3.7.2

*May 12, 2023*

- Fix #192: status codes in 1XX range were considered failures  
- Fix #193: synchronization issue during remote logger initialization

## Pulse 3.7.1

*Apr 30, 2023*

- Fix an issue with `LoggerStore/removeAll` removing current session

## Pulse 3.7.0

*Apr 29, 2023*

- Improve search suggestions on macOS that are now [displayed inline](https://user-images.githubusercontent.com/1567433/235319231-caaabe2f-d173-4dca-b585-203c36ee70cc.png) and support the same search options as on iOS
- Improve how search results are displayed on macOS
- Improve search scope picker and allow searching for in more scopes
- Add support for "Logs" filters: File, Label, Level
- Add strings search options to search on macOS
- Move "Sort By" and "Group" by options to the context menu
- Remove custom Message and Network filters that were replaced by the search introduced in [Pulse 3.2](https://kean.blog/post/pulse-search). These custom filters will continue to be available in Pulse for Mac (coming soon)
- Fix an issue where filters were applies automatically to the search results on macOS
- Fix an issue with `metadata` search being available for network tasks
- Fix proactive search result lookup on macOS
- Fix warnings when updating some observable objects from the background
- Fix an issue with recent search filters not being saved
- Fix an issue with logging on physical tvOS devices
- Fix missing labels in logs
- Fix the navigation bar item design on iOS 14
- Fix the missing back button in the response body on iOS 14

## Pulse 3.6.0

*Apr 22, 2023*

### PulseUI

- Add new ["Sessions" screen](https://user-images.githubusercontent.com/1567433/233789699-08700704-0414-4a54-80af-c4c489d8c1d9.png)) where you can see all the previously recorded runs of the app. Tap on a session to see it in the "Console". Tap "Edit" to select one or more sessions, and then share only the selected sessions, delete them, or open them in the "Console".
- By clicking "Show Previous Session" in the "Console" it now adds only the previous session and not all previous messages like before
- Update the database schema and the remote logger protocol to support the new session management. The changes are still backward compatible with Pulse Pro 2.x, and the the new Pulse for Mac app is coming to TestFlight soon.
- Remove the separate "Share Store" button from "Console" menu. This menu is now available when you press the default "Share" in the console. The time range selection is now based on sessions, not time intervals.
- Add an option to export a store as a macOS package (instead of the archive, which is a default). The package consists of multiple files and makes it easier to view the logger database, but it takes a bit more space and is harder to share as it's essentially a folder.
- Add "Hide..." and "Show..." menus to messages cells to access quick filters

### Pulse

- Deprecate `LoggerStore/copy` method and introduce a new, more powerful `LoggerStore/export` method that allows to specify the document type (`.archive` or `.package`) and filter the output by sessions. This method is async and also no longer blocks the store's background context.
- Add `LoggerStore/removeSessions` method for removing session
- Optimize compression. Now if files don't compress well, `LoggerStore` saves uncompressed data.
- Make `RemoteLogger.Connection` internal (was public)

### Fixes

- Fix [#183](https://github.com/kean/Pulse/issues/183): two close button in `MainViewController`
- Fix an issue with store export where blobs larger than inline were encoded in the final file but were never actually accessible after opening the store
- Fix crash when storing requests with very large timeout interval
- Fix an issue with `.keyNotFound` decoding errors not being displayed
- Fix an issue with pending tasks sometimes not updating to completed
- Fix an issue with the scroll position being reset after scrolling to the bottom and selecting one of the items at the bottom
- Fix an issue with the details view sometimes popping when going to the bottom of the list

## Pulse 3.5.7

*Apr 9, 2023*

- Fix [#180](https://github.com/kean/Pulse/issues/180): crash when sharing requests
- Fix layout for pending requests
- Fix an issue with inconsistent text styles in HTML exports
    
## Pulse 3.5.6

*Apr 6, 2023*

- Fix #167: performance issues with `UITextView` on iOS 16
- Fix #179: console with network mode not filtering out regular logs
- Add `mode` parameter to the `ConsoleView` initializer that, in addition to `.network`, now also supports `.logs` mode (display only text messages)
- ConsoleView now automatically adds a close button when presented (use `closeButtonHidden` if you need to hide it)
- Minor design improvements for cells in the console

## Pulse 3.5.5

*Apr 2, 2023*

- Fix warnings in Xcode 14.3
- Improve Dynamic Type support

## Pulse 3.5.4

*Mar 10, 2023*

- Fix logging on physical tvOS devices – [#173](https://github.com/kean/Pulse/pull/172) by [@mmmcheese](https://github.com/mmmcheese)

## Pulse 3.5.3

*Mar 5, 2023*

- Improve search performance, especially when dealing with big responses (20+ MB) and short search terms (1 character) that result in a massive number of matches
- Fix [#165](https://github.com/kean/Pulse/issues/165): crash in search

## Pulse 3.5.2

*Feb 17, 2023*

- Add Swift 5.8 support – [#164](https://github.com/kean/Pulse/pull/164) by [@thedavidharris](https://github.com/thedavidharris)

## Pulse 3.5.1

*Feb 16, 2023*

- Reduce xcframeworks binary size. Pulse 2.1 MB → 823 KB. PulseUI 7.6 MB → 3.9 MB.
- Reduce PulseUI .swiftmodule size: 4.4 MB → 260 KB.
- When you focus on one of the groups, it now preserves the order of the logs
- On iOS, Insights screen now shows all requests for the current session
- When you open slowest requests, redirects, and failures from the Insights screen, the list now updates automatically as new requests are added

## Pulse 3.5.0

*Feb 11, 2023*

### PulseUI

- Fix [#161](https://github.com/kean/Pulse/issues/161): misleading title for successful local URL requests
- [macOS] Fix an issue where changing sort descriptors in a table view would affect other display modes
- [macOS] Fix an issue where on first selection in a text view or search results list, the main panel would reload 
- The insights view now shows info for the currently selected tasks
- Fix a crash when sharing store and using "This Session" filter

### Pulse

- Address [#162](https://github.com/kean/Pulse/issues/162): Add `label` parameter to `LoggerStore/storeRequest` and `NetworkLogger/Configuration` to allow customizing the label associated with the created logs 
- Remove `NetworkLoggerInsights`

## Pulse 3.4.3

*Feb 9, 2023*

- Fix [#155](https://github.com/kean/Pulse/issues/155): fix an issue with `GTMSessionFetcher` not working correctly with automation `URLSessionProxyDelegate` registration enabled

## Pulse 3.4.2

*Feb 7, 2023*

- [macOS] Update the design to use the transparent toolbar and move the inspectors to the native left sidebar 
- [macOS] Fix an issue with navigation from the metrics screen not working correctly
- [macOS] Move the button to switch from the horizontal to vertical layout to the details view 
- [macOS] Fix an issue with text view not scrolling to the selected match when opened from the full-body console search

## Pulse 3.4.1

*Feb 6, 2023*

- Fix selection not working in search results view on macOS
- Fix transaction details opening an empty page
- Fix a couple of minor issues in light mode on macOS
- Use darker background color for details view (mainly text) on macOS

## Pulse 3.4

*Feb 4, 2023*

- Introduce several features from Pulse Pro to the macOS version of the console

## Pulse 3.3

*Jan 30, 2023*

- Redesign the macOS version of the app and introduce some of the feature from Pulse Pro
- Add the new search that was introduced on iOS in [version 3.2](https://github.com/kean/Pulse/releases/tag/3.2.0)

## Pulse 3.2.2

*Jan 29, 2023*

- Add aucomplete for paths
- Fix labels/domains selection in filters - [#152](https://github.com/kean/Pulse/pull/152) by [hayek](https://github.com/hayek)

## Pulse 3.2.1

*Jan 27, 2023*

- Fix backward compatibility with Pulse Pro 2.x

## Pulse 3.2

*Jan 24, 2023*

- Add new [powerful search](http://kean.blog/post/pulse-search)
- Improve console design
- Add "Sort By" and "Group By" options
- Display pins at the top
- Add "Show Previous Session" button to search
- Other minor changes
- Add metadata search - [#148](https://github.com/kean/Pulse/pull/148) by [@ejensen](https://github.com/ejensen)

## Pulse 3.1

*Jan 14, 2023*

- Update minimum requirements: Swift 5.7 | Xcode 14.0  | iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 12.0
- Add `ConsoleView.network` to other platforms (originally was available only on iOS)
- Fix a couple of minor design issues
- Fix missing live progress in Console for upload and download tasks

### Filters

- New [message](https://user-images.githubusercontent.com/1567433/212389395-2f60e425-cdc5-47ea-9185-52364ce9120c.png) and [network](https://user-images.githubusercontent.com/1567433/212389402-7c5c8f3e-cde2-4654-95e2-98a2844d7d89.png) filters design on macOS
- Add search, expand/collapse, enable-all/disable-all buttons to labels and domains filters on all platforms
- Add a missing "Remove Pins" button on macOS
- Add a counter next to labels and domains
- Display labels and domains only visible for the current filter
- Fix an issue where when you were focusing a log label, it wasn't reflected in the filters
- Fix an issue where using the "Recent" date filter was applying the "Session" filter instead

### Sharing

- Improve task to `NSAttributedString` generation speed by up to 7x faster. For multiple tasks, there is up to x3 improvement on top of that. And when converting multiple tasks with the same request or response body, you can see up to 90% faster exports. These optimizations affect everything: rendering response bodies, lists of messages, request headers, sharing (regardless of the output format), and more.
- Improve HTML generation speed by 40% (not including `NSAttributedString` improvements that directly affect it)
- Add a spinner while preparing a large file for sharing. You can still interact with the app while it's working. Note: it doesn't work with PDF because it has to be used on the main thread.
- Add some [basic formatting](https://user-images.githubusercontent.com/1567433/212501275-1dae0ef8-ee4a-4d77-aa55-24b026e5d0cc.png)) for plain text output to make it easier to read
- Fix double dot in shared files extensions
- Remove share as .pdf from Console and TextView (keep in NetworkInspector) - too slow to be used for any reasonable amount of content

## Pulse 3.0

*Jan 10, 2023*

### Pulse

- Add `includedHosts`, `includedURLs`, `excludedHosts`, and `excludedURLs` to `NetworkLogger/Configuration`. By default, they support simple wildcards, e.g. `*.example.com`, but you can also enable full regex using another new configuration options: `isRegexEnabled`.
- Add `sensitiveHeaders`, `sensitiveQueryItems`, `sensitiveDataFields` to `NetworkLogger/Configuration` for redacting sentitive information from logged HTTP headers 
- Add a new convenience initializer to `NetworkLogger` with `configure` trailing closure
- Make `LoggerStore.Event` frozen

### PulseUI

- A complete overhaul. See https://kean.blog/post/pulse-3 for more details.


# Pulse 2.x

## Pulse 2.1.4

*Dec 18, 2022*

- Fix an issue with tabbar transparency (iOS 15 feature) not always working as expected

## Pulse 2.1.3

*Sep 30, 2022*

- Fix crash when using a custom filter and searching by "label" - [#116](https://github.com/kean/Pulse/issues/116)
- Remove "line" and "function" filters

## Pulse 2.1.2

*Sep 11, 2022*

- Fix build issues with Catalyst on Xcode 14.0 (PulseUI framework) 
- Address warnings on macOS

## Pulse 2.1.1

*Sep 10, 2022*

- Fix a build issue with Catalyst on Xcode 14.0

## Pulse 2.1.0

*Sep 10, 2022*

- Add Xcode 14.0 support

## Pulse 2.0.3

*Aug 22, 2022*

- Fix an issue caught by ConcurrencyDebug - [#104](https://github.com/kean/Pulse/issues/104)

## Pulse 2.0.2

*Aug 19, 2022*

- Fix [#102](https://github.com/kean/Pulse/issues/102) – invalid error type used in `LoggerStore/storeRequest(...)` method
- Fix toolbar icons color on Ventura (macOS)

## Pulse 2.0.1

*Aug 16, 2022*

- Fix a crash when saving connection security details - [#100](https://github.com/kean/Pulse/issues/100#issuecomment-1216826547)

## Pulse 2.0.0

*Aug 15, 2022*

> There are too many changes to list them here.

See [Introducing Pulse 2.0](https://kean.blog/post/pulse-2) to learn about the new major features.


# Pulse 1.x

## Pulse 1.1.0

*May 14, 2022*

- [iOS, watchOS] Update message details design, display custom metadata – [#81](https://github.com/kean/Pulse/pull/81)
- [iOS] Fix an issue with search toolbar not showing up during searching

## Pulse 1.0.3

*May 3, 2022*

- Fix missing tab bar icons on iOS 13 – [#77](https://github.com/kean/Pulse/issues/77)
- Fix Network view filters on iOS 13 – [#77](https://github.com/kean/Pulse/issues/77)
- Fix Time Period filter design on iOS 13 

## Pulse 1.0.2

*Apr 28, 2022*

- Fix [#74](https://github.com/kean/Pulse/issues/74) – crash on Network view
- Fix search bar behavior (replace TextField with UISearchBar)
- Fix gray area at the bottom of MainViewController - [#73](https://github.com/kean/Pulse/pull/73), thanks to [TBXark](https://github.com/TBXark)

## Pulse 1.0.1

*Apr 24, 2022*

- [iOS] Fix labels not loading in console filters

## Pulse 1.0.0

*Apr 23, 2022*

- [iOS] Replace `List` with `UITableView` to address some performance and usability issues
- [iOS] Add console and network filters from Pulse Pro are now available on iOS
- [iOS] Fix an issue with “Remove Messages” button not working on the Console screen
- [iOS] Replace quick filters with "show only errors" button, which is now also available on Network screen. The remaining quick filters are now available on the Filters screen.
- [iOS, watchOS] Add swipe action “Pin” for table cells
- [All] Optimize some search filters
- [iOS] Improve table cells design, allowing for more text to be displayed and making pins more visible 

# Pulse 0.x

## Pulse 0.20.2

*Mar 23, 2022*

- Fix multi-threading crash - [#69](https://github.com/kean/Pulse/pull/69), thanks to [Scott Gruby](https://github.com/sgruby)
- Make `SettingsView` public - [#68](https://github.com/kean/Pulse/pull/68), thanks to [Martin Daum](https://github.com/martindaum)

## Pulse 0.20.1

*Dec 23, 2021*

- Add a default `delegate` value to `URLSessionProxyDelegate`

## Pulse 0.20.0

*Nov 13, 2021*

- Fix [#58](https://github.com/kean/Pulse/issues/58): status code not shown when using `Alamofire.EventMonitor`
- Request headers now display cookies
- Add a way to filter out sensitive information using `NetworkLogger` (see `willLogTask`)
- Add an option to disable sharing

## Pulse 0.19.4

*Nov 5, 2021*

- Fix compilation on Xcode 13.2 beta - [#54](https://github.com/kean/Pulse/issues/54)

## Pulse 0.19.3

*Oct 19, 2021*

- Remove unused `PulseInternal` target - [#51](https://github.com/kean/Pulse/pull/51), thanks to [Agapov Alexey](https://github.com/AgapovOne)

## Pulse 0.19.2

*Oct 18, 2021*

- Fix an issue with a URL hardcoded for testing on the summary page

## Pulse 0.19.1

*18 Oct, 2021*

- Temporarily remove `PulseInternal`

## Pulse 0.19.0

*17 Oct, 2021*

### PulseCore

- Rename the folder that Pulse creates in Logs/ directory to `com.github.kean.logger`. Previously, it was using `.pulse` as a suffix which was conflicting with the extension used for [Pulse documents](https://kean.blog/post/pulse-store) - [#48](https://github.com/kean/Pulse/pull/48), thanks to [Agapov Alexey](https://github.com/AgapovOne)
- Add `filename` to `LoggerMessageEntity`
- Add URLSession configuration information to logged network requests, including [httpAdditionalHeaders](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/1411532-httpadditionalheaders)
- Coalesce disk writes to reduce disk usage
- Perform less work on the logger's caller's thread
- Catch all Objective-C exceptions (just in case)
- Fix a warning that the logger would write into the console during initialization

### PulseUI

- [All Platforms] Display [additional HTTP headers](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/1411532-httpadditionalheaders) - [#41](https://github.com/kean/Pulse/issues/41)

## Pulse 0.18.0

*4 Oct, 2021*

- [PulseCore] Add `RemoteLogger` (requires Pulse Pro releasing on Oct 5)
- [PulseCore] Store pins persistently and add the respective APIs to `LoggerStore`
- [PulseCore] Add new fields to the entities: `levelOrder`, `contentType`, `requestState`
- [PulseCore] Add `LoggerStore.Info.AppInfo` with an app name, bundle identifier, and other information about the app to the Pulse documents
- [PulseCore] Opening a (readonly) Pulse document with an unsupported scheme will now throw an error
- [PulseCore] Pins are now stored persistently and are exported along with the store. Add APIs for managing pins in `LoggerStore`
- [iOS] Display new `LoggerStore.Info.AppInfo` when opening an existing store
- [All Platforms] Improved JSON color theme matching Xcode

## Pulse 0.17.2

*15 Sep, 2021*

- Add Xcode 13 support - [#39](https://github.com/kean/Pulse/pull/39), thanks to [Jeffrey Macko](https://github.com/mackoj)

## Pulse 0.17.1

*13 Sep, 2021*

- Add support to httpBodyStreamData - [#37](https://github.com/kean/Pulse/pull/37), thanks to [Klemen Košir](https://github.com/klemenkosir)
- Fix an issue where cURL share was using request body instead of the response body - [#38](https://github.com/kean/Pulse/pull/38), thanks to [BB9z](https://github.com/BB9z)

## Pulse 0.17.0

*11 Sep, 2021*

- Add `storeRequest(_,response:error:data:metrics)` method to `LoggerStore`. It can be used if you just want to log the response without incremental updates. For incremental updates, use the existing `NetworkLogger` class instead.
- Fix a crash occurring when you invalidate a `URLSession` that uses `URLSessionProxyDelegate` - [#36](https://github.com/kean/Pulse/issues/36)
- Fix an issue where `URLSessionProxyDelegate` was not retaining the real delegate the way `URLSession` does
- [iOS] Display a context menu with all available options (plain text, HTML, cURL) etc when pressing "Share" button in a network request details screen on iOS 14
- [HTML export] Add soft-wrap for long header fields
- [HTML export] Add proper overflow for response bodies
- Automatically remove appearance overrides for navigation bar in MainViewController; some break SwiftUI layout (if you need to disable it, use isAutomaticAppearanceOverrideRemovalEnabled.isAutomaticAppearanceOverrideRemovalEnabled)
- [iOS] Limit the size of text values in key-value sections to 4 lines
- [iOS] Add a way to view raw error description
- New icon for "Network"
- Fix missing closing parentheses in error description in an error section

## Pulse 0.16.1

*24 Aug, 2021*

- Fix an issue with 0 and 1 being printed as Boolean values by the JSON printer – [#34](https://github.com/kean/Pulse/pull/34), thanks to [Abdula Magomedov](https://github.com/abdula571) 

## Pulse 0.16.0

*21 Aug, 2021*

- Fix crash with URLSession automatic session registration - [#31](https://github.com/kean/Pulse/pull/31), thanks to [Ivan Lisovyi](https://github.com/ivanlisovyi) 
- `ConsoleView`, `NetworkView`, and `PinsView` are no longer wrapped into `NavigationView` by default. It gives you more integration options. For example, you can now push a `ConsoleView` into your own `UINavigationControllers` (or `NavigationViews`).
- Add `onDismiss` parameter to `MainViewController` and `MainView` to show a close button
- Make `PinsView` initializer public
- Make Pulse compatible with earlier Xcode versions (at least down to Xcode 12.4)
- [iOS] Add a "Remove Messages" button directly to the console
- Remove `date` parameter from `storeMessage` (`LoggerStore`) and add default parameters for file, function

## Pulse 0.15.3

*7 Jul, 2021*

- Fix archive actions for a macOS app

## Pulse 0.15.2

*2 Jul, 2021*

- Fix [#19](https://github.com/kean/Pulse/issues/19) – fails to present a file browser

## Pulse 0.15.1

*27 Apr, 2021*

- Add a missing `CFBundleVersion`.

## Pulse 0.15.0

*21 Apr, 2021*

### PulseUI

- Add HTML export for network requests
- When using a Markdown export, add `.markdown` file extension

### PulseCore
- Add `URLSessionProxyDelegate.enableAutomaticRegistration()` for more convenient proxy registration

## Pulse 0.14.2

*19 Apr, 2021*

Initial public release. See [**Pulse Docs**](https://kean.blog/pulse/home) for more info.

- Frameworks are distributed as SPM packages (using XCFramework) and are also attached to this release
- iOS app is currently available as an open beta at https://testflight.apple.com/join/1jcanE3q
- macOS app attached to the release https://github.com/kean/Pulse/releases/download/0.14.2/Pulse.app.zip

## Pulse 0.14.1

*Mar 30, 2021*

Performance improvements on iOS, tvOS, watchOS

## Pulse 0.14.0

*Mar 29, 2021*

### macOS
- Fix an issue when displaying errors for store issues 

### tvOS
- Initial release of UI components

### iOS
- Fix disclosure indicators in horizontal mode

### Internal
- Remove @EnvironmentObject usage (still has defects)

## Pulse 0.12.0

*Mar 27, 2021*

### Pulse
- Add new `LoggerStoreOptions.sweep` that automatically reduces store size when needed by removing the least recently added messages and blobs
- Make `LoggerStore.Options` a nested type

### macOS
- Improve window management on macOS
- Add commands: Open, Open Recent
- Display recent documents on the welcome screen (replaces onDrop which became useless after Pulse document type addition)

### iOS
- Remove link detection when viewing headers
- Add formatting when viewing raw headers (bold header names)

### tvOS
- Initial release (no UI, just logger)

## Pulse 0.11.0

*Mar 21, 2021*

### Pulse
- Add Pulse document type. It can be either a readonly archive (for sharing) for a package (for editing). [Read here](https://kean.blog/post/pulse-store).
- Remove `LoggerStore(name:)` initializer
- Rework and document `LoggerStore` initializer
- Add `LoggerStore.empty` (can be used as a fallback to throwing init), `LoggerStore.archiveURL`
- Add experimental `URLSessionProxy`
- Add public API to control blob size limit (`LoggerStore.blobsSizeLimit`)
- Add `LoggerStore.sweep` API and instead of logs expiration interval use size limit (`LoggerStore.databaseSizeLimit`)
- Add `Experimental.URLSessionProxy`

### iOS
- Introduce a document-based "Pulse" iOS app to view logs (in addition to an SDK that you can integrate into your app). Beta coming soon.
- Integrate a document browser to view stored files (replaces ad-hoc "Archive" introduce in Pulse 0.10)

### macOS
- Performance improvements 
- Fix "Copy cURL" context action
- Add "Copy response" context action
- Fix an issue with search in text viewer when multiple windows are open

### watchOS
- Improve quick filters screen, now automatically dismissed after selecting a filter

## Pulse 0.10.0

*Mar 14, 2021*

- [watchOS] Initial watchOS version.
- [iOS] Add a separate option to share a store as text
- [iOS] Fix sharing to Dropbox, Outlook
- [macOS] Fix an issue when sometimes outdated logs will get deleted when viewing archived store
- [macOS] More performance improvements
- [macOS] Fix pin management when multiple stores are open
- [Pulse] Add custom document type with ".pulse" extension. The file is a deflated zip archive that contains blobs, database, and store manifest
- [Pulse] Add new APIs for `LoggerMessageStore`:
	- `archive()` creates a store archive (.pulse file)
	- `copyStore(at:)`
	- `allNetworkRequests()`
- [Pulse] Remove `BlobStore` and all associated APIs, it's now managed automatically by `LoggerMessageStore`

## Pulse 0.9.9

*Mar 7, 2021*

- Display request duration right in the list
- Add Catalyst support

## Pulse 0.9.7

*Mar 2, 2021*

macOS-only release

- Add more performance improvements on macOS
- Fix a couple of search-related issues

## Pulse 0.9.6

*Mar 1, 2021*

- Multiple performance optimizations across the board. Pulse now effortlessly support 50.000+ logs. More optimizations to come in the future versions.

## Fixes

- Fix an issue with sharing network messages from the list on iOS
- Fix case-sensitive text search
- Fix search when log levels are all disabled
- Fix an issue where a Mac app would sometimes remove messages (add new readonly LoggerMessageStore option)

## Pulse 0.9.5

*Feb 20, 2021*

- Initial macOS version is now available
- Fix an issue where text disappears during search (iOS)

> macOS demo attached to the release as .pkg (see private repo)

## Pulse 0.9.4

*Feb 13, 2021*

- Fix Settings navigation on iPad (use stacked style)
- Add placeholders on iPad for when no navigation item is selected
- Move search toolbar in response viewer to the bottom, this way the fingers don't cover the screen when iterating between matches
- Add search to regular message details view
- Add haptic feedback
- Add "View Raw" buttons to response and request headers
- Fix foreground color for raw text views
- Remove "Response" and "Request" tabs and instead add "View Raw" buttons directly to the "Summary" page. This way viewer has more vertical space and can have its own dedicated navigation bar items. It's also easier to reach, especially after tapping on one of the messages.
- Add "Share" button to response viewer, works both for text and images
- UI improvements

## Pulse 0.9.3

*Feb 11, 2021*

- Display image pixel size in image response viewer
- Fix layout issues in response viewer on smaller devices
- Add more network request examples in the demo: image response, big JSON response (2500 lines)
- Optimize response text view, now interactive search is able to handle 2000+ lines of text
- Hide keyboard when moving between matches in response text view
- `NetworkLogger` to send "start request" events with `.trace` level
- Disable autocapitalization and autocorrection in search bars
- Fix cell highlighting when search bar clear button is tapped

## Pulse 0.9.2

*Feb 10, 2021*

- Add default initializers for PulseUI views
- Add `MainViewController` for easier UIKit integration
- Pulse now be installed on as low as iOS 11. Console will only work on iOS 13, but `MainViewController` is available on iOS 11 and will show "Console is only available in iOS 13 and higher" when running on iOS 12 or lower
- Rename `LoggerView` to `MainView`
- Fix an issue with mock store creation

## Pulse 0.9.1

*Feb 9, 2021*

- Fix URLSessionProxyDelegate delegate issue where some events weren't recorded properly
- Remove `ConsoleSearchCriteria`, `ConsoleShareService` and some other types from the public interface which were not meant to be there
- Fix regex crash when using constructs that might produce empty matches, e.g. empty side of an alternation
- Advanced text view with search can now be used with all types of text-based responses, not just JSON

## Pulse 0.9.0

*Feb 8, 2021*

**iOS**

- Refined message list UI
- Add quick filters for easy access to commonly used filters
- Add an easy way to reset filters
- Network viewer (using tabs)
- Add "Pins" tab. Pin messages by either using a context menu or by going to the details screen.
- Add new filters: select any combinations of log levels to display, or set cuastom date interval
- Dedicated share sheet for network messages:
    - Share as plain text, markdown, or cURL command
    - Copy URL, host, or response
- Better placeholders
- Add badge to details screen with message status
- In addition to JSON, response body viewer now supports more content types: plain text, images
- You can now copy HTTP header keys and values
- Copy or share response/request in Network Inspector
- In case of a URLError, display both the code and the short description in the list
- Network tab. Search based on method, path, parameters - anything
- Add powerful search to Response view

**macOS**

- Update is work in progress

**Fixes**

- Fix an issue where "Remove All" button was not removing blobs, only messages
- Fix edge insets on inspector screens and use inline style for pushed screens titles
- Fix an issue with empty headers rendering
- Fix an issue with timeline rendering with cache lookup
- Search is now case-insensitive 

## Pulse 0.8.1

*Feb 6, 2021*

- Move `NetworkLogger` and other related types to `Pulse`
- Remove mock stores from `PulseUI` public interfaces
- Simplify project structure using Swift Package Manager local dependencies
- Fix Release compilation

## Pulse 0.8.0

*Feb 5, 2021*

- `NetworkLogger` is now created with a default logger and blob store
- Add `URLSessionProxyDelegate` to automate `URLSession` task logging
- Add [a guide](https://github.com/kean/PulseUI/blob/0.8.0/Docs/Logging.md) on logging network events

## Pulse 0.7.0

*Feb 4, 2021*

- Remove UserDefaults sharing from share service
- Response and Request blobs are now stored in a dedicated BlobStore, essentially filesystem. The store has a size limit and uses LRU algorithm for cleanup. BlobStore also deduplicates the blobs, so if the app receives the same response multiple times, only one blob is stored.
- You can open a Pulse store on macOS be selecting a directory with a store, not just the store itself
- Refined view for message list on iOS
- Special messages list cells for network requests

## Pulse 0.6.0

*Feb 1, 2021*

- Add Network Inspector

## Pulse 0.5.0

*Jan 28, 2021*

- Add Big Sur support
- Add iOS 14 support
- Update to support "label" filters on macOS
- Add "trace" filter support, "trace" messages are no longer visible by default

## Pulse 0.4.0

*May 6, 2020*

- Update to Pulse 0.3

## Pulse 0.3.0

*May 4, 2020*

- Update package dependency to no longer use local dependencies

## Pulse 0.2.0

*May 4, 2020*

- Optimize search queries

## Pulse 0.1.0

*May 3, 2020*

- Initial version
