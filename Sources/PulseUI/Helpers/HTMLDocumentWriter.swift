// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import Foundation

/// Combines the documents created by ``TextUtilities/html(from:)`` into a
/// single HTML file, writing each one as soon as it is appended.
final class HTMLDocumentWriter {
    private let handle: FileHandle
    private var documentCount = 0

    init(url: URL) throws {
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        handle = try FileHandle(forWritingTo: url)
    }

    deinit {
        try? handle.close()
    }

    /// Returns a placeholder to render in place of a large body, which is then
    /// passed to ``append(_:largeBodies:)`` to be written without conversion.
    static func makePlaceholder() -> String {
        "pulse-large-body-\(UUID().uuidString)"
    }

    /// - parameter largeBodies: The texts to write in place of the placeholders
    /// created with ``makePlaceholder()``. Each placeholder must take a
    /// paragraph of its own.
    func append(_ document: Data, largeBodies: [String: String] = [:]) throws {
        guard let html = NSString(data: document, encoding: NSUTF8StringEncoding) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        let bodyStart = html.range(of: "<body>")
        let bodyEnd = html.range(of: "</body>", options: .backwards)
        let styleStart = html.range(of: "<style type=\"text/css\">")
        let styleEnd = html.range(of: "</style>")
        guard bodyStart.location != NSNotFound, bodyEnd.location != NSNotFound,
              styleStart.location != NSNotFound, styleEnd.location != NSNotFound,
              styleEnd.location < bodyStart.location else {
            throw CocoaError(.fileWriteUnknown)
        }

        // Each document names its styles "p1", "s1", and so on, so the names
        // have to be made unique before the documents are combined.
        let prefix = "d\(documentCount)-"
        let style = html.substring(with: NSRange(location: styleStart.upperBound, length: styleEnd.location - styleStart.upperBound))
        let renamedStyle = Self.styleClassRegex.stringByReplacingMatches(
            in: style,
            range: NSRange(location: 0, length: (style as NSString).length),
            withTemplate: ".\(prefix)$1"
        )
        // The text inside the body is escaped, so every "class=\"" is an attribute.
        let body = html.substring(with: NSRange(location: bodyStart.upperBound, length: bodyEnd.location - bodyStart.upperBound))
            .replacingOccurrences(of: "class=\"", with: "class=\"\(prefix)")

        if documentCount == 0 {
            try write(html.substring(to: styleStart.upperBound))
            try write(renamedStyle)
            try write(html.substring(with: NSRange(location: styleEnd.location, length: bodyStart.upperBound - styleEnd.location)))
        } else {
            try write("<style type=\"text/css\">")
            try write(renamedStyle)
            try write("</style>")
        }
        try write(body, largeBodies: largeBodies)
        documentCount += 1
    }

    private func write(_ body: String, largeBodies: [String: String]) throws {
        var remaining = body[...]
        while !largeBodies.isEmpty, let match = remaining.range(of: "pulse-large-body-") {
            let placeholderEnd = remaining.index(match.upperBound, offsetBy: 36, limitedBy: remaining.endIndex) ?? remaining.endIndex
            let placeholder = String(remaining[match.lowerBound..<placeholderEnd])
            guard let text = largeBodies[placeholder],
                  let paragraph = remaining[..<match.lowerBound].range(of: "<p ", options: .backwards),
                  let tagEnd = remaining[paragraph.upperBound..<match.lowerBound].firstIndex(of: ">") else {
                try write(String(remaining[..<placeholderEnd]))
                remaining = remaining[placeholderEnd...]
                continue
            }
            // Keeps the paragraph and its fonts, but preserves the line breaks
            // and indentation without an element per line.
            try write(String(remaining[..<tagEnd]))
            try write(#" style="white-space: pre-wrap""#)
            try write(String(remaining[tagEnd..<match.lowerBound]))
            try write(text
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;"))
            remaining = remaining[placeholderEnd...]
        }
        try write(String(remaining))
    }

    /// - returns: The size of the written document.
    func finish() throws -> Int64 {
        try write("</body>\n</html>\n")
        return Int64(try handle.offset())
    }

    private func write(_ string: String) throws {
        try handle.write(contentsOf: Data(string.utf8))
    }

    /// Matches selectors like "p.p1" and "span.s1".
    private static let styleClassRegex = try! NSRegularExpression(pattern: #"\.([a-z]+\d+)\b"#)
}
