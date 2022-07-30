// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation

struct DurationFormatter {
    static func string(from timeInterval: TimeInterval, isPrecise: Bool = true) -> String {
        if timeInterval < 0.95 {
            return String(format: "%.1fms", timeInterval * 1000)
        }
        if timeInterval < 200 {
            return String(format: "%.\(isPrecise ? "3" : "1")fs", timeInterval)
        }
        let minutes = timeInterval / 60
        if minutes < 60 {
            return String(format: "%.1fmin", minutes)
        }
        let hours = timeInterval / (60 * 60)
        return String(format: "%.1fh", hours)
    }
}

struct StatusCodeFormatter {
    static func string(for statusCode: Int32) -> String {
        string(for: Int(statusCode))
    }

    static func string(for statusCode: Int) -> String {
        switch statusCode {
        case 200: return "200 OK"
        default: return "\(statusCode) \( HTTPURLResponse.localizedString(forStatusCode: statusCode).capitalized)"
        }
    }
}
