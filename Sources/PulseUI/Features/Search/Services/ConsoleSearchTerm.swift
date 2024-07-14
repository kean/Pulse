// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation

struct ConsoleSearchTerm: Identifiable, Hashable, Codable {
    var id: ConsoleSearchTerm { self }

    var text: String
    var options: StringSearchOptions
}
