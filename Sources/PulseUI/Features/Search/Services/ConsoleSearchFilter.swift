// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse

protocol ConsoleSearchFilterProtocol: Equatable, Hashable, Codable {
    var name: String { get }
    var valuesDescriptions: [String] { get }
    var valueExample: String { get }

    func isMatch(_ task: NetworkTaskEntity) -> Bool
}

enum ConsoleSearchFilter: Equatable, Hashable, Codable {
    case statusCode(ConsoleSearchFilterStatusCode)
    case host(ConsoleSearchFilterHost)

    // TODO: refactor
    var filter: any ConsoleSearchFilterProtocol {
        switch self {
        case .statusCode(let filter): return filter
        case .host(let filter): return filter
        }
    }

    var name: String { filter.name }
    var valuesDescriptions: [String] { filter.valuesDescriptions }
    var valueExample: String { filter.valueExample }
}

struct ConsoleSearchFilterStatusCode: ConsoleSearchFilterProtocol {
    var values: [ConsoleSearchRange<Int>]

    var name: String { "Status Code" }
    var valuesDescriptions: [String] { values.map(\.title) }
    var valueExample: String { "200" }

    func isMatch(_ task: NetworkTaskEntity) -> Bool {
        values.compactMap { $0.range }.contains {
            $0.contains(Int(task.statusCode))
        }
    }
}

struct ConsoleSearchFilterHost: ConsoleSearchFilterProtocol {
    var values: [String]

    var name: String { "Host" }
    var valuesDescriptions: [String] { values }
    var valueExample: String { "example.com" }

    func isMatch(_ task: NetworkTaskEntity) -> Bool {
        guard let host = task.url.flatMap(URL.init)?.host else {
            return false
        }
        return values.contains { host.contains($0) }
    }
}

enum ConsoleSearchRangeModfier: Codable {
    case open, closed
}

struct ConsoleSearchRange<T: Hashable & Comparable & Codable>: Hashable, Codable {
    var modifier: ConsoleSearchRangeModfier
    var lowerBound: T
    var upperBound: T

    init(_ modifier: ConsoleSearchRangeModfier, lowerBound: T, upperBound: T) {
        self.modifier = modifier
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }

    init(_ value: T) {
        self.modifier = .closed
        self.lowerBound = value
        self.upperBound = value
    }

    var title: String {
        guard upperBound > lowerBound else { return "\(lowerBound)" }
        switch modifier {
        case .open: return "\(lowerBound)..<\(upperBound)"
        case .closed: return "\(lowerBound)...\(upperBound)"
        }
    }
}

extension ConsoleSearchRange where T == Int {
    var range: ClosedRange<Int>? {
        guard upperBound >= lowerBound else { return nil }
        switch modifier {
        case .open: return ClosedRange(lowerBound..<upperBound)
        case .closed: return lowerBound...upperBound
        }
    }
}
