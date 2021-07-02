# Pulse 0.x

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
- Fix an issue when dispay errors for store issues 

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
- Fix an issue with search in text viewer when multple windows are open

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
- Add an easy way to reset fitlers
- Network viwer (using tabs)
- Add "Pins" tab. Pin messages by either using a context menu or by going to the details screen.
- Add new filters: select any combinations of log levels to display, or set cuastom date interval
- Dedicated share sheet for network messages:
    - Share as plain text, markdown, or cURL command
    - Copy URL, host, or response
- Better placeholders
- Add badge to details screen with message status
- In addition to JSON, response body viewer now supports more content types: plain text, images
- You can now copy HTTP header keys and values
- Copy or share respones/request in Network Inspector
- In case of a URLError, display both thte code and the short descrition in the list
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
- Response and Request blobs are now stored in a dedicated BlobStore, essentially filesystem. The store has a size limit and uses LRU algorithm for cleanup. BlobStore also deduplicates the blobs, so if the app recieves the same response multiple times, only one blob is stored.
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

- Update package depenency to no longer use local dependencies

## Pulse 0.2.0

*May 4, 2020*

- Optimize search queries

## Pulse 0.1.0

*May 3, 2020*

- Initial version
