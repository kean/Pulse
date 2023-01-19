// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation

struct ConsoleSearchTerm: Hashable, Codable {
    var text: String
    var options: StringSearchOptions
}
