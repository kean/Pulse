// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse

protocol ConsoleSearchFilterProtocol: Equatable, Hashable, Codable {
    var name: String { get }
    var valuesDescriptions: [String] { get }
    var valueExample: String { get }
    var token: String { get }

    func isMatch(_ task: NetworkTaskEntity) -> Bool
}

extension ConsoleSearchFilterProtocol {
    var token: String { makeToken(with: valuesDescriptions) }
}

enum ConsoleSearchFilter: Equatable, Hashable, Codable {
    case statusCode(ConsoleSearchFilterStatusCode)
    case host(ConsoleSearchFilterHost)
    case method(ConsoleSearchFilterMethod)

    // TODO: refactor
    var filter: any ConsoleSearchFilterProtocol {
        switch self {
        case .statusCode(let filter): return filter
        case .host(let filter): return filter
        case .method(let filter): return filter
        }
    }

    var name: String { filter.name }
    var valuesDescriptions: [String] { filter.valuesDescriptions }
    var valueExample: String { filter.valueExample }
    var token: String { filter.token }
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

struct ConsoleSearchFilterMethod: ConsoleSearchFilterProtocol {
    var values: [HTTPMethod]

    var name: String { "Method" }
    var valuesDescriptions: [String] { values.map(\.rawValue) }
    var valueExample: String { "GET" }

    func isMatch(_ task: NetworkTaskEntity) -> Bool {
        guard let method = HTTPMethod(rawValue: task.httpMethod ?? "") else { return false }
        return Set(values).contains(method)
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

private func makeToken(with values: [String]) -> String {
    guard values.count > 0 else { return "–" } // Should never happen
    let title = values[0]
    return values.count > 1 ? title + "…" : title
}
