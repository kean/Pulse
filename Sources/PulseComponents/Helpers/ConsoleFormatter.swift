// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation

public enum ConsoleFormatter {
    public enum StatusCodeFormatter {
        public static func string(for statusCode: Int32) -> String {
            string(for: Int(statusCode))
        }

        public static func string(for statusCode: Int) -> String {
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

}
