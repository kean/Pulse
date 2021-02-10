# Pulse 0.x

## Pulse 0.7.0

*Feb 8, 2021*

- Split the project into `PulseCore` (no dependencies) and `Pulse` (depends on `Apple/SwiftLog`). `PulseCore` requires dynamic linkage. All these changes are required to make `PulseUI` XCFramework to work: it should be able to link to `PulseCore` dynamically.
- `PersistentLogHandler` now respects default metadata set for `Logger` 

## Pulse 0.6.1

*Feb 7, 2021*

- `NetworkLogger` no longer saves `.trace` events by default 

## Pulse 0.6.0

*Feb 5, 2021*

- Add `NetworkLogger` along with the related types (`NetworkLoggerEvent`, `BlobStore`, etc)

## Pulse 0.5.0

*Feb 4, 2021*

- Add support for "networkEventCreatedAt" metadata values (network logger specific)

## Pulse 0.4.0

*May 7, 2020*

- Store `.string` and `.stringConvertible` metadata using new `MetadataEntity` entities
- Rename `LoggerMessage` to `MessageEntity` to avoid confusion with `SwiftLog` types
- Store `file`, `function`, and `line` information

## Pulse 0.3.0

*May 6, 2020*

- Reimplement Pulse from the ground up to be based on [swift-log](https://github.com/apple/swift-log) - [#2](https://github.com/kean/Pulse/pull/2), by [Moritz Lang](https://github.com/slashmo)
- Lower minimum platform requirements to iOS 11.0 / watchOS 4.0 / macOS 10.13 / tvOS 11.0
- Store logs in Library/Logs directory (non-user data), the directory is excluded from the backup
- Add `LoggerMessageStore.init(storeURL:)`

## Pulse 0.2.0

*May 4, 2020*

- `Logger` now automatically removes outdated messages.
- Add `Logger.logsExpirationInterval` property, the default value is 7 days.

## Pulse 0.1.0

*May 3, 2020*

- Initial version
