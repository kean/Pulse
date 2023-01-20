// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import XCTest
@testable import Pulse
@testable import PulseUI

final class StringSearchOptionsTests: XCTestCase {
    func testsStringSearchOptions() throws {
        let input = "github.com test test-string 123" as NSString

        XCTAssertEqual(
            input.ranges(of: "git???..om", options: .init(kind: .wildcard)),
            []
        )

        // Default
        XCTAssertEqual(
            input.ranges(of: "test", options: .init()),
            [NSRange(location: 11, length: 4), NSRange(location: 16, length: 4)]
        )

        // Begins with
        XCTAssertEqual(
            input.ranges(of: "test", options: .init(rule: .begins)),
            []
        )
        XCTAssertEqual(
            input.ranges(of: "github", options: .init(rule: .begins)),
            [NSRange(location: 0, length: 6)]
        )

        // Ends with
        XCTAssertEqual(
            input.ranges(of: "test", options: .init(rule: .begins)),
            []
        )
        XCTAssertEqual(
            input.ranges(of: "123", options: .init(rule: .ends)),
            [NSRange(location: 28, length: 3)]
        )

        // Wildcard
        XCTAssertEqual(
            input.ranges(of: "github.*", options: .init(kind: .wildcard)),
            [NSRange(location: 0, length: 10)]
        )
        XCTAssertEqual(
            input.ranges(of: "github.*", options: .init(kind: .wildcard)),
            [NSRange(location: 0, length: 10)]
        )
        XCTAssertEqual(
            input.ranges(of: "git???.com", options: .init(kind: .wildcard)),
            [NSRange(location: 0, length: 10)]
        )
        // Wildcard (test that metacharacters are escaped
        XCTAssertEqual(
            input.ranges(of: "git???..om", options: .init(kind: .wildcard)),
            []
        )
        XCTAssertEqual(
            input.ranges(of: "test-*", options: .init(kind: .wildcard)),
            [NSRange(location: 16, length: 11)]
        )
        XCTAssertEqual(
            input.ranges(of: "test-*", options: .init(kind: .wildcard, rule: .begins)),
            []
        )
        XCTAssertEqual(
            input.ranges(of: "?23", options: .init(kind: .wildcard, rule: .ends)),
            [NSRange(location: 28, length: 3)]
        )
        XCTAssertEqual(
            "[()]123".ranges(of: "[()]*", options: .init(kind: .wildcard)),
            [NSRange(location: 0, length: 7)]
        )

        // Regex
        XCTAssertEqual(
            input.ranges(of: "te.t", options: .init(kind: .regex)),
            [NSRange(location: 11, length: 4), NSRange(location: 16, length: 4)]
        )
    }
}
