import XCTest
@testable import Herald

final class HeraldTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(Herald().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
