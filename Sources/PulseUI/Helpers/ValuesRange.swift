// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

// Can't use `Swift.Range` because values are immutable.
package struct ValuesRange<T> {
    package var lowerBound: T
    package var upperBound: T

    package init(lowerBound: T, upperBound: T) {
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }
}

extension ValuesRange: Equatable where T: Equatable {}
extension ValuesRange: Hashable where T: Hashable {}
extension ValuesRange: Codable where T: Codable {}

extension ValuesRange where T == String {
    package static let empty = ValuesRange(lowerBound: "", upperBound: "")
}
