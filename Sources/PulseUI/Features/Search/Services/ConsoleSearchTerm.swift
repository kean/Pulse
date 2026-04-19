// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import Foundation

package struct ConsoleSearchTerm: Identifiable, Hashable, Codable {
    package var id: ConsoleSearchTerm { self }

    package var text: String
    package var options: StringSearchOptions

    package init(text: String, options: StringSearchOptions) {
        self.text = text
        self.options = options
    }
}

package struct ConsoleSearchMatch {
    package let line: String
    /// Starts with `1.
    package let lineNumber: Int
    package let range: Range<String.Index>
    package let term: ConsoleSearchTerm

    package static let limit = 6

    package init(line: String, lineNumber: Int, range: Range<String.Index>, term: ConsoleSearchTerm) {
        self.line = line
        self.lineNumber = lineNumber
        self.range = range
        self.term = term
    }
}
