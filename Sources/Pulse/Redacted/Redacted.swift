import Foundation

public struct Redacted: Sendable {
    /// Store logs only for the included hosts.
    ///
    /// - note: Supports wildcards, e.g. `*.example.com`, and full regex
    /// when ``isRegexEnabled`` option is enabled.
    public var includedHosts: Set<String> = []

    /// Store logs only for the included URLs.
    ///
    /// - note: Supports wildcards, e.g. `*.example.com`, and full regex
    /// when ``isRegexEnabled`` option is enabled.
    public var includedURLs: Set<String> = []

    /// Exclude the given hosts from the logs.
    ///
    /// - note: Supports wildcards, e.g. `*.example.com`, and full regex
    /// when ``isRegexEnabled`` option is enabled.
    public var excludedHosts: Set<String> = []

    /// Exclude the given URLs from the logs.
    ///
    /// - note: Supports wildcards, e.g. `*.example.com`, and full regex
    /// when ``isRegexEnabled`` option is enabled.
    public var excludedURLs: Set<String> = []

    /// Redact the given HTTP headers from the logged requests and responses.
    ///
    /// - note: Supports wildcards, e.g. `X-*`, and full regex
    /// when ``isRegexEnabled`` option is enabled.
    public var sensitiveHeaders: Set<String> = []

    /// Redact the given query items from the URLs.
    ///
    /// - note: Supports only plain strings. Case-sensitive.
    public var sensitiveQueryItems: Set<String> = []

    /// Redact the given JSON fields from the logged requests and responses bodies.
    ///
    /// - note: Supports only plain strings. Case-sensitive.
    public var sensitiveDataFields: Set<String> = []

    /// If enabled, processes `include` and `exclude` patterns using regex.
    /// By default, patterns support only basic wildcard syntax: `*.example.com`.
    public var isRegexEnabled = false

    public init() {}

    func patterns() -> Patterns {
        func process(_ pattern: String) -> Regex? {
            process(pattern, options: [])
        }

        func process(_ pattern: String, options: [Regex.Options]) -> Regex? {
            do {
                let pattern = isRegexEnabled ? pattern : expandingWildcards(pattern)
                return try Regex(pattern)
            } catch {
                debugPrint("Failed to parse pattern: \(pattern) \(error)")
                return nil
            }
        }

        func expandingWildcards(_ pattern: String) -> String {
            let pattern = NSRegularExpression.escapedPattern(for: pattern)
                .replacingOccurrences(of: "\\?", with: ".")
                .replacingOccurrences(of: "\\*", with: "[^\\s]*")
            return "^\(pattern)$"
        }

        return Patterns(
            includedHosts: includedHosts.compactMap(process),
            includedURLs: includedURLs.compactMap(process),
            excludedHosts: excludedHosts.compactMap(process),
            excludedURLs: excludedURLs.compactMap(process),
            sensitiveHeaders: sensitiveHeaders.compactMap {
                process($0, options: [.caseInsensitive])
            },
            sensitiveQueryItems: sensitiveQueryItems,
            sensitiveDataFields: sensitiveDataFields,
            isFilteringNeeded: !includedHosts.isEmpty || !excludedHosts.isEmpty || !includedURLs.isEmpty || !excludedURLs.isEmpty
        )
    }
}
