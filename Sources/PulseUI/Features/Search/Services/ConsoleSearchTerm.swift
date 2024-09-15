// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

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
