import CoreGraphics
import XCTest
@testable import OpenMultiDisplay

final class DisplayArrangementTests: XCTestCase {
    func testFallbackStartsAfterWholeDesktopWhenExternalDisplayIsRightOfMain() {
        let main = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let rightExternal = CGRect(x: 1512, y: 0, width: 1920, height: 1080)
        let upperExternal = CGRect(x: 685, y: -1080, width: 1920, height: 1080)

        let origins = DisplayArrangement.fallbackOrigins(
            existingDisplayBounds: [main, rightExternal, upperExternal],
            anchorDisplayBounds: main,
            virtualDisplaySizes: [CGSize(width: 1600, height: 1200)],
            spacing: 40
        )

        XCTAssertEqual(origins, [CGPoint(x: 3472, y: 0)])
    }

    func testFallbackUsesDesktopUnionWithNegativeCoordinates() {
        let leftExternal = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        let main = CGRect(x: 0, y: 0, width: 1512, height: 982)

        let origins = DisplayArrangement.fallbackOrigins(
            existingDisplayBounds: [leftExternal, main],
            anchorDisplayBounds: main,
            virtualDisplaySizes: [CGSize(width: 1920, height: 1200)],
            spacing: 40
        )

        XCTAssertEqual(origins, [CGPoint(x: 1552, y: 0)])
    }

    func testMultipleFallbackDisplaysDoNotOverlapEachOther() {
        let main = CGRect(x: 0, y: 0, width: 1512, height: 982)

        let origins = DisplayArrangement.fallbackOrigins(
            existingDisplayBounds: [main],
            anchorDisplayBounds: main,
            virtualDisplaySizes: [
                CGSize(width: 1600, height: 1200),
                CGSize(width: 1920, height: 1200)
            ],
            spacing: 40
        )

        XCTAssertEqual(origins, [
            CGPoint(x: 1552, y: 0),
            CGPoint(x: 3192, y: 0)
        ])
    }

    func testFallbackWithoutExistingDisplaysStartsAtOrigin() {
        let origins = DisplayArrangement.fallbackOrigins(
            existingDisplayBounds: [],
            anchorDisplayBounds: nil,
            virtualDisplaySizes: [CGSize(width: 800, height: 600)],
            spacing: 40
        )

        XCTAssertEqual(origins, [CGPoint(x: 0, y: 0)])
    }
}
