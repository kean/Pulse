// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import XCTest
@testable import Pulse
@testable import PulseUI

@available(iOS 15, tvOS 15, *)
final class ConsoleSearchServiceTests: XCTestCase {
    let service = ConsoleSearchService()

    func testThatMultipleFiltersOfTheSameTypeAreCombined() throws {
        // GIVEN
        let entity = LoggerStore.preview.entity(for: .login)
        let parameters = ConsoleSearchParameters(tokens: [
            .filter(.statusCode(.init(values: [.init(200)]))),
            .filter(.statusCode(.init(values: [.init(204)])))
        ])

        // WHEN
        let occurrences = try XCTUnwrap(service.search(entity, parameters: parameters))

        // THEN
        XCTAssertEqual(occurrences.count, 0)
    }
}
