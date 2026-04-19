// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import Foundation

/// A user-defined filter that matches console entries (log messages or network
/// tasks) against a text value using configurable search options.
///
/// Each filter targets a specific ``Field``, which maps to a Core Data attribute
/// on `LoggerMessageEntity` or `NetworkTaskEntity`. Use ``makePredicate()`` to
/// produce an `NSPredicate` for use in a fetch request, or ``matches(string:)``
/// for in-memory filtering.
package struct ConsoleCustomFilter: Hashable, Identifiable {
    package let id = UUID()
    /// The entity field to match against (e.g. `.message`, `.url`).
    package var field: Field
    /// How the ``value`` is compared to the field (kind, case sensitivity, rule).
    package var match: StringSearchOptions
    /// When `true`, the predicate is inverted — the filter passes entries that
    /// do *not* match the value.
    package var isNegated: Bool = false
    /// The text to search for.
    package var value: String
    /// Whether this filter participates in the active filter set.
    package var isEnabled: Bool = true

    package init(field: Field, match: StringSearchOptions = .default, isNegated: Bool = false, value: String, isEnabled: Bool = true) {
        self.field = field
        self.match = match
        self.isNegated = isNegated
        self.value = value
        self.isEnabled = isEnabled
    }

    /// A short human-readable label for the targeted field (e.g. `"URL"`).
    package var fieldTitle: String { field.title }

    /// A short human-readable description of the match rule, optionally
    /// prefixed with `"Not "` when the filter is negated.
    package var matchTitle: String { (isNegated ? "Not " : "") + match.title }

    /// Returns a copy of this filter with a new ``id``.
    package func duplicated() -> ConsoleCustomFilter {
        ConsoleCustomFilter(field: field, match: match, isNegated: isNegated, value: value, isEnabled: isEnabled)
    }

    package static func == (lhs: ConsoleCustomFilter, rhs: ConsoleCustomFilter) -> Bool {
        (lhs.field, lhs.match, lhs.isNegated, lhs.value, lhs.isEnabled) == (rhs.field, rhs.match, rhs.isNegated, rhs.value, rhs.isEnabled)
    }

    package func hash(into hasher: inout Hasher) {
        field.hash(into: &hasher)
        match.hash(into: &hasher)
        isNegated.hash(into: &hasher)
        value.hash(into: &hasher)
        isEnabled.hash(into: &hasher)
    }

    /// Returns an `NSPredicate` suitable for a Core Data fetch request on the
    /// entity that owns ``field``. When ``isNegated`` is `true`, the predicate
    /// is wrapped in `NSCompoundPredicate(notPredicateWithSubpredicate:)`.
    package func makePredicate() -> NSPredicate {
        let predicate = match.predicate(key: field.key, value: value)
        return isNegated ? NSCompoundPredicate(notPredicateWithSubpredicate: predicate) : predicate
    }

    /// Returns `true` when `string` satisfies the filter's match options.
    /// Applies negation when ``isNegated`` is `true`.
    ///
    /// Use this for in-memory matching where a Core Data fetch is not involved.
    package func matches(string: String) -> Bool {
        let result = match.matches(string, value: value)
        return isNegated ? !result : result
    }
}

// MARK: - Codable

// `id` is a per-instance UUID used only for SwiftUI list identity. It must not
// round-trip through JSON, otherwise re-applying a recent filter would clash
// with the live one. Custom Codable regenerates `id` on decode.
extension ConsoleCustomFilter: Codable {
    private enum CodingKeys: String, CodingKey {
        case field, match, isNegated, value, isEnabled
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            field: try container.decode(Field.self, forKey: .field),
            match: try container.decode(StringSearchOptions.self, forKey: .match),
            isNegated: try container.decode(Bool.self, forKey: .isNegated),
            value: try container.decode(String.self, forKey: .value),
            isEnabled: try container.decode(Bool.self, forKey: .isEnabled)
        )
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(field, forKey: .field)
        try container.encode(match, forKey: .match)
        try container.encode(isNegated, forKey: .isNegated)
        try container.encode(value, forKey: .value)
        try container.encode(isEnabled, forKey: .isEnabled)
    }
}

// MARK: - Field

extension ConsoleCustomFilter {
    /// Identifies which entity attribute a ``ConsoleCustomFilter`` targets.
    ///
    /// ``title`` is shown in the UI; ``key`` is the Core Data attribute name
    /// passed to `StringSearchOptions.predicate(key:value:)`.
    package struct Field: Hashable, Codable {
        package var title: String
        package var key: String

        package init(title: String, key: String) {
            self.title = title
            self.key = key
        }
    }

    /// A titled group of fields for display in a picker with visual separators.
    package struct FieldGroup: Hashable {
        package var title: String?
        package var fields: [Field]

        package init(title: String? = nil, fields: [Field]) {
            self.title = title
            self.fields = fields
        }
    }
}

// MARK: - Message Fields

extension ConsoleCustomFilter {
    /// Ordered list of fields available when filtering `LoggerMessageEntity`.
    package static let messageFields: [Field] = [.level, .label, .message, .metadata, .file]

    /// Message fields wrapped in a single group (no section header needed).
    package static let messageFieldGroups: [FieldGroup] = [
        FieldGroup(fields: messageFields)
    ]

    package var availableFieldGroups: [FieldGroup] {
        if Self.messageFields.contains(field) {
            return Self.messageFieldGroups
        } else {
            return Self.networkFieldGroups
        }
    }

    package static func defaultMessageFilter() -> ConsoleCustomFilter {
        ConsoleCustomFilter(field: .message, match: .default, value: "")
    }
}

extension ConsoleCustomFilter.Field {
    /// Matches `LoggerMessageEntity.level` (stored as a raw `Int16`).
    package static let level = ConsoleCustomFilter.Field(title: "Level", key: "level")
    package static let label = ConsoleCustomFilter.Field(title: "Label", key: "label")
    /// Matches `LoggerMessageEntity.text`.
    package static let message = ConsoleCustomFilter.Field(title: "Message", key: "text")
    /// Matches `LoggerMessageEntity.rawMetadata` (newline-separated `key: value` pairs).
    package static let metadata = ConsoleCustomFilter.Field(title: "Metadata", key: "rawMetadata")
    package static let file = ConsoleCustomFilter.Field(title: "File", key: "file")
}

// MARK: - Network Fields

extension ConsoleCustomFilter {
    /// Network fields organized into groups for the field picker.
    package static let networkFieldGroups: [FieldGroup] = [
        FieldGroup(title: "URL", fields: [.url, .host, .path]),
        FieldGroup(fields: [.method, .statusCode, .errorCode, .errorDomain]),
        FieldGroup(title: "Advanced", fields: [.taskDescription, .requestHeader, .responseHeader])
    ]
    /// All network fields (flattened from groups).
    package static let allNetworkFields: [Field] = networkFieldGroups.flatMap(\.fields)

    package static func defaultNetworkFilter() -> ConsoleCustomFilter {
        ConsoleCustomFilter(field: .url, match: .default, value: "")
    }
}

extension ConsoleCustomFilter.Field {
    package static let url = ConsoleCustomFilter.Field(title: "URL", key: "url")
    package static let host = ConsoleCustomFilter.Field(title: "Host", key: "host")
    /// Matches `NetworkTaskEntity.path`.
    package static let path = ConsoleCustomFilter.Field(title: "Path", key: "path")
    package static let method = ConsoleCustomFilter.Field(title: "Method", key: "httpMethod")
    /// Matches `NetworkTaskEntity.statusCode` (stored as `Int32`).
    package static let statusCode = ConsoleCustomFilter.Field(title: "Status Code", key: "statusCode")
    /// Matches `NetworkTaskEntity.errorCode` (stored as `Int32`).
    package static let errorCode = ConsoleCustomFilter.Field(title: "Error Code", key: "errorCode")
    package static let errorDomain = ConsoleCustomFilter.Field(title: "Error Domain", key: "errorDomain")
    /// Matches `NetworkTaskEntity.taskDescription`.
    package static let taskDescription = ConsoleCustomFilter.Field(title: "Task Description", key: "taskDescription")
    /// Matches headers on `NetworkRequestEntity` via a keypath predicate.
    package static let requestHeader = ConsoleCustomFilter.Field(title: "Request Headers", key: "originalRequest.httpHeaders")
    /// Matches headers on `NetworkResponseEntity` via a keypath predicate.
    package static let responseHeader = ConsoleCustomFilter.Field(title: "Response Headers", key: "response.httpHeaders")
}
