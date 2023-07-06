// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse

enum DurationFormatter {
    static func string(from timeInterval: TimeInterval) -> String {
        string(from: timeInterval, isPrecise: true)
    }

    static func string(from timeInterval: TimeInterval, isPrecise: Bool) -> String {
        if timeInterval < 0.95 {
            if isPrecise {
                return String(format: "%.1f ms", timeInterval * 1000)
            } else {
                return String(format: "%.0f ms", timeInterval * 1000)
            }
        }
        if timeInterval < 200 {
            return String(format: "%.\(isPrecise ? "3" : "1")f s", timeInterval)
        }
        let minutes = timeInterval / 60
        if minutes < 60 {
            return String(format: "%.1f min", minutes)
        }
        let hours = timeInterval / (60 * 60)
        return String(format: "%.1f h", hours)
    }
}

extension DateFormatter {
    /// With timezone, so that if it's shared, we know the exact time.
    static let fullDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.dateFormat = "MMM d, yyyy 'at' h:mm:ss a '('z')'"
        return dateFormatter
    }()

    convenience init(dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style, isRelative: Bool = false) {
        self.init()
        self.dateStyle = dateStyle
        self.timeStyle = timeStyle
        self.doesRelativeDateFormatting = isRelative
        self.locale = Locale(identifier: "en_US")
    }
}

enum ConsoleFormatter {
    static let separator = " · "

    static func subheadline(for message: LoggerMessageEntity, hasTime: Bool = true) -> String {
        return [
            hasTime ? time(for: message.createdAt) : nil,
            message.logLevel.name.uppercased(),
            label(for: message)
        ].compactMap { $0 }.joined(separator: separator)
    }

    static func label(for message: LoggerMessageEntity) -> String? {
        let label = message.label
        guard label != "default", !label.isEmpty else {
            return nil
        }
        return label.capitalized
    }

    static func subheadline(for task: NetworkTaskEntity, hasTime: Bool = true) -> String {
        return [
            hasTime ? time(for: task.createdAt) : nil,
            task.httpMethod ?? "GET",
            status(for: task),
            transferSize(for: task),
            duration(for: task)
        ].compactMap { $0 }.joined(separator: separator)
    }

    /// Example:
    ///
    /// "GET · Pending"
    /// "GET · 21.9 MB · 2.2s"
    static func details(for task: NetworkTaskEntity) -> String {
        return [
            transferSize(for: task),
            duration(for: task),
            progress(for: task)
        ].compactMap { $0 }.joined(separator: separator)
    }

    // MARK: Individual Components

    static func time(for date: Date) -> String {
        if #available(iOS 15, *) {
            return ConsoleMessageCell.timeFormatter.string(from: date)
        } else {
            return ""
        }
    }

    static func status(for task: NetworkTaskEntity) -> String {
        switch task.state {
        case .pending:
            return ProgressViewModel.title(for: task)
        case .success:
            return StatusCodeFormatter.string(for: Int(task.statusCode))
        case .failure:
            return ErrorFormatter.shortErrorDescription(for: task)
        }
    }

    static func transferSize(for task: NetworkTaskEntity) -> String? {
        guard task.state == .success else {
            return nil
        }
        switch task.type ?? .dataTask {
        case .uploadTask:
            if task.requestBodySize > 0 {
                return ByteCountFormatter.string(fromByteCount: task.requestBodySize)
            }
        case .dataTask, .downloadTask:
            if task.responseBodySize > 0 {
                return ByteCountFormatter.string(fromByteCount: task.responseBodySize)
            }
        case .streamTask, .webSocketTask:
            break
        }
        return nil
    }

    static func duration(for task: NetworkTaskEntity) -> String? {
        guard task.duration > 0 else { return nil }
        return DurationFormatter.string(from: task.duration, isPrecise: false)
    }

    static func progress(for task: NetworkTaskEntity) -> String? {
        ProgressViewModel.details(for: task)
    }
}

enum StatusCodeFormatter {
    static func string(for statusCode: Int32) -> String {
        string(for: Int(statusCode))
    }

    static func string(for statusCode: Int) -> String {
        switch statusCode {
        case 0: return "Success"
        case 200: return "200 OK"
        case 418: return "418 Teapot"
        case 429: return "429 Too many requests"
        case 451: return "451 Unavailable for Legal Reasons"
        default: return "\(statusCode) \( HTTPURLResponse.localizedString(forStatusCode: statusCode).capitalized)"
        }
    }
}

enum ErrorFormatter {
    static func shortErrorDescription(for task: NetworkTaskEntity) -> String {
        if task.errorCode != 0 {
            if task.errorDomain == URLError.errorDomain {
                return descriptionForURLErrorCode(Int(task.errorCode))
            } else if task.errorDomain == NetworkLogger.DecodingError.domain {
                return "Decoding Failed"
            } else {
                return "Error"
            }
        } else {
            return StatusCodeFormatter.string(for: Int(task.statusCode))
        }
    }
}

extension ByteCountFormatter {
    static func string(fromBodySize count: Int64) -> String? {
        guard count > 0 else {
            return nil
        }
        return string(fromByteCount: count)
    }

    static func string(fromByteCount count: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
    }
}

enum CountFormatter {
    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    static func string(from count: Int) -> String {
        if count < 1000 { return "\(count)" }
        let number = NSNumber(floatLiteral: Double(count) / 1000.0)
        return (numberFormatter.string(from: number) ?? "–") + "k"
    }
}
