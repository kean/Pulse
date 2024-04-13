// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS) || os(visionOS)

import XCTest
import Combine
@testable import Pulse
@testable import PulseUI

final class ConsoleSearchOccurrenceTests: XCTestCase {
    func testMakeSimplePreview() throws {
        guard #available(iOS 15, macOS 13, *) else { return }

        // GIVEN short string
        let string = #"{"id":"2489678844","type":"IssuesEvent","actor":{"id":9343331,"login":"No-CQRT","avatar_url":"https://avatars.githubusercontent.com/u/9343331?"}}"#

        // GIVEN match somewhere in the middle
        let term = ConsoleSearchTerm(text: "actor", options: .default)
        let range = try XCTUnwrap(string.range(of: term.text))
        let match = ConsoleSearchMatch(line: string, lineNumber: 1, range: range, term: term)

        // WHEN
        let preview = ConsoleSearchOccurrence.makePreview(for: match)

        // THEN the entire string fits in the preview
        XCTAssertEqual(String(preview.characters), string)
    }

    func testThatWhitespacesAndPunctuationsAreTrimmed() throws {
        guard #available(iOS 15, macOS 13, *) else { return }

        // GIVEN
        let string = #"   {"id":"2489678844","type":"IssuesEvent","actor":{"id":9343331,"login":"No-CQRT","avatar_url":"https://avatars.githubusercontent.com/u/9343331?"}},  "#

        // GIVEN match somewhere in the middle
        let term = ConsoleSearchTerm(text: "actor", options: .default)
        let range = try XCTUnwrap(string.range(of: term.text))
        let match = ConsoleSearchMatch(line: string, lineNumber: 1, range: range, term: term)

        // WHEN
        let preview = ConsoleSearchOccurrence.makePreview(for: match)

        // THEN whitespaces and punctiation characters are trimmmed
        XCTAssertEqual(String(preview.characters), #"{"id":"2489678844","type":"IssuesEvent","actor":{"id":9343331,"login":"No-CQRT","avatar_url":"https://avatars.githubusercontent.com/u/9343331?"}}"#)
    }

    func testMatchAtBeginning() throws {
        guard #available(iOS 15, macOS 13, *) else { return }

        // GIVEN
        let string = #"{"id":"2489678844","type":"IssuesEvent","actor":{"id":9343331,"login":"No-CQRT","avatar_url":"https://avatars.githubusercontent.com/u/9343331?"}}"#

        // GIVEN match somewhere in the middle
        let term = ConsoleSearchTerm(text: #"{"id""#, options: .default)
        let range = try XCTUnwrap(string.range(of: term.text))
        let match = ConsoleSearchMatch(line: string, lineNumber: 1, range: range, term: term)

        // WHEN
        let preview = ConsoleSearchOccurrence.makePreview(for: match)

        // THEN suffix is trimmed
        XCTAssertEqual(String(preview.characters), #"{"id":"2489678844","type":"IssuesEvent","actor":{"id":9343331,"login":"No-CQRT","avatar_url":"https://avatars.githubusercontent.com/u/9343331?"}}"#)
    }

    func testMatchAtEnd() throws {
        guard #available(iOS 15, macOS 13, *) else { return }

        // GIVEN
        let string = #"{"id":"2489678844","type":"IssuesEvent","actor":{"id":9343331,"login":"No-CQRT","avatar_url":"https://avatars.githubusercontent.com/u/9343331?"}}"#

        // GIVEN match somewhere in the middle
        let term = ConsoleSearchTerm(text: #"9343331?"}}"#, options: .default)
        let range = try XCTUnwrap(string.range(of: term.text))
        let match = ConsoleSearchMatch(line: string, lineNumber: 1, range: range, term: term)

        // WHEN
        let preview = ConsoleSearchOccurrence.makePreview(for: match)

        // THEN prefix is trimmed
        XCTAssertEqual(String(preview.characters), #"…tar_url":"https://avatars.githubusercontent.com/u/9343331?"}}"#)
    }
}

#endif
