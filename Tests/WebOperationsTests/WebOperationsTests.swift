import XCTest
@testable import WebOperations

final class WebOperationsTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(WebOperations().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
