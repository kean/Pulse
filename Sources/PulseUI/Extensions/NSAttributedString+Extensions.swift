// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation

extension NSMutableAttributedString {
    package func append(_ string: String, _ attributes: [NSAttributedString.Key: Any] = [:]) {
        append(NSAttributedString(string: string, attributes: attributes))
    }

    package func addAttributes(_ attributes: [NSAttributedString.Key: Any]) {
        addAttributes(attributes, range: NSRange(location: 0, length: string.count))
    }
}
