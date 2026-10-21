import XCTest
@testable import UpdateNotice

final class VersionTests: XCTestCase {
    private func v(_ string: String) -> Version { Version(string)! }

    func testNewerAndOlder() {
        XCTAssertTrue(v("2.0.5") > v("2.0.4"))
        XCTAssertTrue(v("2.0.4") < v("2.1.0"))
        XCTAssertTrue(v("3.0.0") > v("2.9.9"))
    }

    func testComparesNumbersNotStrings() {
        XCTAssertTrue(v("2.0.10") > v("2.0.9"))
    }

    func testMissingComponentsCountAsZero() {
        XCTAssertEqual(v("2.0"), v("2.0.0"))
        XCTAssertEqual(v("2"), v("2.0.0"))
        XCTAssertTrue(v("2.0.1") > v("2.0"))
        XCTAssertFalse(v("2.0") < v("2.0.0"))
    }

    func testEqualVersions() {
        XCTAssertEqual(v("2.0.4"), v("2.0.4"))
        XCTAssertEqual(v("2.0.4").hashValue, v("2.0.4.0").hashValue)
    }

    func testLeadingVAndWhitespaceAreAccepted() {
        XCTAssertEqual(v("v2.0.4"), v("2.0.4"))
        XCTAssertEqual(v(" 2.0.4\n"), v("2.0.4"))
    }

    func testMalformedStringsAreRejected() {
        for bad in ["", "abc", "2..4", "2.0.x", "2.0.4-beta", "-1", ".", "2.0.", "\u{0662}.0"] {
            XCTAssertNil(Version(bad), bad)
        }
    }

    func testDescription() {
        XCTAssertEqual(v("v2.0.10").description, "2.0.10")
    }
}
