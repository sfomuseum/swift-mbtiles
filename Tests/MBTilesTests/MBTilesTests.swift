import XCTest
@testable import MBTiles

final class MBTilesTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(MBTiles().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
