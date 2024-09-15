// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import SwiftUI
import CoreData

package enum LoggerEntity {
    /// Regular log, not task attached.
    case message(LoggerMessageEntity)
    /// Either a log with an attached task, or a task itself.
    case task(NetworkTaskEntity)

    package init(_ entity: NSManagedObject) {
        if let message = entity as? LoggerMessageEntity {
            if let task = message.task {
                self = .task(task)
            } else {
                self = .message(message)
            }
        } else if let task = entity as? NetworkTaskEntity {
            self = .task(task)
        } else {
            fatalError("Unsupported entity: \(entity)")
        }
    }

    package var task: NetworkTaskEntity? {
        if case .task(let task) = self { return task }
        return nil
    }
}

extension LoggerMessageEntity {
    package var logLevel: LoggerStore.Level {
        LoggerStore.Level(rawValue: level) ?? .debug
    }
}

extension NetworkTaskEntity.State {
    package var tintColor: Color {
        switch self {
        case .pending: return .orange
        case .success: return .green
        case .failure: return .red
        }
    }

    package var iconSystemName: String {
        switch self {
        case .pending: return "clock.fill"
        case .success: return "checkmark.circle.fill"
        case .failure: return "exclamationmark.octagon.fill"
        }
    }
}

extension LoggerSessionEntity {
    package var formattedDate: String {
        formattedDate(isCompact: false)
    }

    package var searchTags: [String] {
        possibleFormatters.map { $0.string(from: createdAt) }
    }

    package func formattedDate(isCompact: Bool = false) -> String {
        if isCompact {
            return compactDateFormatter.string(from: createdAt)
        } else {
            return fullDateFormatter.string(from: createdAt)
        }
    }

    package var fullVersion: String? {
        guard let version = version else {
            return nil
        }
        if let build = build {
            return version + " (\(build))"
        }
        return version
    }
}

private let compactDateFormatter = DateFormatter(dateStyle: .none, timeStyle: .medium)

#if os(watchOS)
private let fullDateFormatter = DateFormatter(dateStyle: .short, timeStyle: .short, isRelative: true)
#else
private let fullDateFormatter = DateFormatter(dateStyle: .medium, timeStyle: .medium, isRelative: true)
#endif

private let possibleFormatters: [DateFormatter] = [
    fullDateFormatter,
    DateFormatter(dateStyle: .long, timeStyle: .none),
    DateFormatter(dateStyle: .short, timeStyle: .none)
]

#if !os(watchOS)

extension NetworkTaskEntity {
    package func cURLDescription() -> String {
        guard let request = currentRequest ?? originalRequest,
              let url = request.url else {
            return "$ curl command generation failed"
        }

        var components = ["curl -v"]

        components.append("-X \(request.httpMethod ?? "GET")")

        for header in request.headers {
            let escapedValue = header.value.replacingOccurrences(of: "\"", with: "\\\"")
            components.append("-H \"\(header.key): \(escapedValue)\"")
        }

        if let httpBodyData = requestBody?.data {
            let httpBody = String(decoding: httpBodyData, as: UTF8.self)
            var escapedBody = httpBody.replacingOccurrences(of: "\\\"", with: "\\\\\"")
            escapedBody = escapedBody.replacingOccurrences(of: "\"", with: "\\\"")
            components.append("-d \"\(escapedBody)\"")
        }

        components.append("\"\(url)\"")

        return components.joined(separator: " \\\n\t")
    }
}

#endif

extension NetworkTaskEntity {
    package struct InfoItem: Identifiable {
        package let id = UUID()
        package let field: ConsoleListDisplaySettings.TaskField
        package let value: String

        package var title: String {
            switch field {
            case .method: return "HTTP Method"
            case .requestSize: return "Request Size"
            case .responseSize: return "Response Size"
            case .responseContentType: return "Response Content Type"
            case .duration: return "Duration"
            case .host: return "Host"
            case .statusCode: return "Status Code"
            case .taskType: return "Task Type"
            case .taskDescription: return "Task Description"
            case .requestHeaderField(let name): return name
            case .responseHeaderField(let name): return name
            }
        }
    }

    package func makeInfoItem(for field: ConsoleListDisplaySettings.TaskField) -> InfoItem? {
        guard let value = makeInfoText(for: field) else { return nil }
        return InfoItem(field: field, value: value)
    }

    package func makeInfoText(for field: ConsoleListDisplaySettings.TaskField) -> String? {
        switch field {
        case .method:
            httpMethod
        case .requestSize:
            byteCount(for: requestBodySize)
        case .responseSize:
            byteCount(for: responseBodySize)
        case .responseContentType:
            responseContentType.map(NetworkLogger.ContentType.init)?.lastComponent.uppercased()
        case .duration:
            ConsoleFormatter.duration(for: self)
        case .host:
            host
        case .statusCode:
            statusCode != 0 ? statusCode.description : nil
        case .taskType:
            NetworkLogger.TaskType(rawValue: taskType)?.urlSessionTaskClassName
        case .taskDescription:
            taskDescription
        case .requestHeaderField(let key):
            (currentRequest?.headers ?? [:])[key]
        case .responseHeaderField(let key):
            (response?.headers ?? [:])[key]
        }
    }

    package func getShortTitle(options: ConsoleListDisplaySettings) -> String {
        if options.content.showTaskDescription, let taskDescription, !taskDescription.isEmpty {
            return taskDescription
        }
        guard let url else {
            return ""
        }
        return URL(string: url)?.lastPathComponent ?? url
    }

    package func getFormattedContent(settings: ConsoleListDisplaySettings.ContentSettings) -> String? {
        if settings.showTaskDescription, let taskDescription, !taskDescription.isEmpty {
            return taskDescription
        }
        guard let url else {
            return nil
        }
        return NetworkTaskEntity.formattedURL(url, components:  settings.components)
    }

    package static func formattedURL(_ url: String, components displayed: Set<ConsoleListDisplaySettings.URLComponent>) -> String? {
        guard !displayed.isEmpty else {
            return nil
        }
        guard var components = URLComponents(string: url) else {
            return nil
        }
        if displayed.count == 1 && displayed.first == .path {
            return components.path // optimization
        }
        if !(components.password ?? "").isEmpty {
            components.password = "_"
        }
        if !displayed.contains(.scheme) { components.scheme = nil }
        if !displayed.contains(.user) { components.user = nil }
        if !displayed.contains(.password) { components.password = nil }
        if !displayed.contains(.host) { components.host = nil }
        if !displayed.contains(.port) { components.port = nil }
        if !displayed.contains(.path) { /* can't remove path */ }
        if !displayed.contains(.query) { components.query = nil }
        if !displayed.contains(.fragment) { components.fragment = nil }
        guard var string = components.string else {
            return nil
        }
        if string.hasPrefix("//") { // remove phantom scheme
            string.removeFirst(2)
        }
        return string
    }
}

private func byteCount(for size: Int64) -> String {
    guard size > 0 else { return "0 KB" }
    return ByteCountFormatter.string(fromByteCount: size)
}
