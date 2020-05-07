# Pulse 0.x

- Reimplement Pulse from the ground up to be based on [swift-log](https://github.com/apple/swift-log) - [#2](https://github.com/kean/Pulse/pull/2), by [Moritz Lang](https://github.com/slashmo)
- Lower minimum platform requirements to iOS 11.0 / watchOS 4.0 / macOS 10.13 / tvOS 11.0
- Store logs in Library/Logs directory (non-user data), the directory is excluded from the backup

## Pulse 0.2.0

*May 4, 2020*

- `Logger` now automatically removes outdated messages.
- Add `Logger.logsExpirationInterval` property, the default value is 7 days.

## Pulse 0.1.0

*May 3, 2020*

- Initial version
