// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation

#if os(iOS) || os(macOS)

extension NSAttributedString {
    func getLines() -> [NSAttributedString] {
        let matches = newLineRegex.matches(in: string, options: [], range: NSRange(location: 0, length: length))
        var startIndex = 0
        var lines: [NSRange] = []
        for match in matches where match.numberOfRanges > 0 {
            let range = match.range(at: 0)
            lines.append(NSRange(location: startIndex, length: range.location - startIndex))
            startIndex = range.location + range.length
        }
        lines.append(NSRange(location: startIndex, length: length - startIndex))

        var output: [NSAttributedString] = []
        for range in lines {
            let line = attributedSubstring(from: range)
            output.append(line)
        }
        return output
    }
}

private let newLineRegex = try! NSRegularExpression(pattern: "\n", options: [])

#endif

extension NSMutableAttributedString {
    func append(_ string: String, _ attributes: [NSAttributedString.Key: Any] = [:]) {
        append(NSAttributedString(string: string, attributes: attributes))
    }

    func addAttributes(_ attributes: [NSAttributedString.Key: Any]) {
        addAttributes(attributes, range: NSRange(location: 0, length: string.count))
    }
}
