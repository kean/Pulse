// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import SwiftUI

/// Allows customization of ``ConsoleView`` behavior on a per-task basis.
///
/// By default, the console uses the global ``UserSettings/shared`` to decide
/// how to render every network task. Provide a ``ConsoleDelegate`` to vary
/// the display options per task — including injecting custom strings into
/// the header / footer via ``ConsoleListDisplaySettings/TaskField/custom(_:)``
/// or into the content via ``ConsoleListDisplaySettings/ContentSettings/customText``.
@MainActor
public protocol ConsoleDelegate: AnyObject {
    /// Returns the display options to use when rendering the given network
    /// task in the console list and inspector.
    ///
    /// The default implementation returns ``UserSettings/shared``
    /// `listDisplayOptions`.
    func console(listDisplayOptionsFor task: NetworkTaskEntity) -> ConsoleListDisplaySettings

    /// Returns additional context menu items to append to the task cell's
    /// context menu, or `nil` to show only the built-in items.
    ///
    /// The returned view is rendered inside the cell's context menu after the
    /// built-in sections. Typical uses include app-specific actions like
    /// "Replay", "Open in admin panel", or "Copy decoded payload".
    ///
    /// ```swift
    /// func console(contextMenuFor task: NetworkTaskEntity) -> AnyView? {
    ///     AnyView(
    ///         Section {
    ///             Button("Replay") { replay(task) }
    ///         }
    ///     )
    /// }
    /// ```
    func console(contextMenuFor task: NetworkTaskEntity) -> AnyView?

    /// Returns a SwiftUI view that replaces the cell's main content area
    /// (the HTTP method + URL text) when rendering the given task, or `nil`
    /// to use the default content rendering.
    ///
    /// When non-nil, this supersedes ``ConsoleListDisplaySettings/ContentSettings``
    /// entirely — `showMethod`, `showTaskDescription`, `components`,
    /// `customText`, `isMonospaced`, `lineLimit`, and `fontSize` are all
    /// ignored for this task. The header and footer still render from
    /// ``ConsoleListDisplaySettings`` as usual.
    ///
    /// ```swift
    /// func console(contentViewFor task: NetworkTaskEntity) -> AnyView? {
    ///     guard isGraphQL(task) else { return nil }
    ///     return AnyView(GraphQLOperationLabel(task: task))
    /// }
    /// ```
    func console(contentViewFor task: NetworkTaskEntity) -> AnyView?

    /// Returns a SwiftUI view that replaces the built-in response body
    /// viewer for the given task, or `nil` to use the default rendering.
    ///
    /// Use this hook to decode and display formats the built-in viewer
    /// doesn't understand — most notably protobuf, where the integrator
    /// owns the schema / generated `SwiftProtobuf` types. The returned view
    /// replaces the `FileViewer` entirely; wrap the decoded output in a
    /// rich text viewer to reuse the standard search / line-number UI.
    ///
    /// ```swift
    /// func console(responseBodyViewFor task: NetworkTaskEntity) -> AnyView? {
    ///     guard task.response?.contentType?.isProtobuf == true,
    ///           let data = task.responseBody?.data else { return nil }
    ///     let decoded = try? MyProtobufMessage(serializedBytes: data)
    ///     return AnyView(ProtobufMessageView(message: decoded))
    /// }
    /// ```
    func console(responseBodyViewFor task: NetworkTaskEntity) -> AnyView?

    /// Returns a SwiftUI view to inject into the network inspector for the
    /// given task, or `nil` to show only the built-in sections.
    ///
    /// The returned view is rendered as an additional section after the
    /// built-in response/metrics sections. Typical uses include decoded
    /// GraphQL variables, parsed protobuf, or business-context metadata
    /// that the built-in inspector doesn't know how to render.
    ///
    /// ```swift
    /// func console(inspectorViewFor task: NetworkTaskEntity) -> AnyView? {
    ///     guard isGraphQL(task) else { return nil }
    ///     return AnyView(
    ///         Section("GraphQL") {
    ///             GraphQLOperationView(task: task)
    ///         }
    ///     )
    /// }
    /// ```
    func console(inspectorViewFor task: NetworkTaskEntity) -> AnyView?

    /// Returns a redacted version of `value` for safe display, for example
    /// to mask auth tokens or user identifiers before they are rendered in
    /// the console list or the inspector header.
    ///
    /// Called for URL, host, header, task-description, and caller-supplied
    /// strings shown in the task cell. The default implementation returns
    /// `value` unchanged.
    ///
    /// ```swift
    /// func console(redact value: String, field: ConsoleRedactionField, for task: NetworkTaskEntity) -> String {
    ///     switch field {
    ///     case .requestHeader("Authorization"): return "Bearer ***"
    ///     case .url: return value.replacingOccurrences(of: #/token=[^&]+/#, with: "token=***")
    ///     default: return value
    ///     }
    /// }
    /// ```
    func console(redact value: String, field: ConsoleRedactionField, for task: NetworkTaskEntity) -> String
}

extension ConsoleDelegate {
    public func console(listDisplayOptionsFor task: NetworkTaskEntity) -> ConsoleListDisplaySettings {
        UserSettings.shared.listDisplayOptions
    }

    public func console(contextMenuFor task: NetworkTaskEntity) -> AnyView? {
        nil
    }

    public func console(inspectorViewFor task: NetworkTaskEntity) -> AnyView? {
        nil
    }

    public func console(responseBodyViewFor task: NetworkTaskEntity) -> AnyView? {
        nil
    }

    public func console(contentViewFor task: NetworkTaskEntity) -> AnyView? {
        nil
    }

    public func console(redact value: String, field: ConsoleRedactionField, for task: NetworkTaskEntity) -> String {
        value
    }
}

/// Identifies which string the console is about to render, passed to
/// ``ConsoleDelegate/console(redact:field:for:)`` so integrators can target
/// specific fields for redaction.
public enum ConsoleRedactionField: Sendable, Hashable {
    /// The URL or a URL component displayed as cell content or in a field.
    case url
    /// The `host` component displayed in a field.
    case host
    /// A request header value (e.g., `Authorization`).
    case requestHeader(String)
    /// A response header value (e.g., `Set-Cookie`).
    case responseHeader(String)
    /// The `URLSessionTask.taskDescription` rendered as cell content or in a field.
    case taskDescription
    /// A caller-supplied custom string (``ConsoleListDisplaySettings/TaskField/custom(_:)``
    /// or ``ConsoleListDisplaySettings/ContentSettings/customText``).
    case custom
}
