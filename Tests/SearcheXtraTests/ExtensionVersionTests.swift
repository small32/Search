import XCTest
@testable import SearcheXtra

final class ExtensionVersionTests: XCTestCase {
    func testNumericVersionOrdering() throws {
        XCTAssertTrue(try ExtensionVersion.isNewer("1.10", than: "1.9"))
        XCTAssertTrue(try ExtensionVersion.isNewer("2", than: "1.99.99.99"))
        XCTAssertFalse(try ExtensionVersion.isNewer("1.2.0.0", than: "1.2"))
        XCTAssertFalse(try ExtensionVersion.isNewer("1.9", than: "1.10"))
        XCTAssertFalse(try ExtensionVersion.isNewer("2.0.17", than: "2.0.17"))
    }
    func testInvalidVersionsCannotBeTreatedAsUpdates() {
        XCTAssertThrowsError(try ExtensionVersion.isNewer("not-a-version", than: "1"))
        XCTAssertThrowsError(try ExtensionVersion.isNewer("65536", than: "1"))
        XCTAssertThrowsError(try ExtensionVersion.isNewer("1.2.3.4.5", than: "1"))
    }
}
