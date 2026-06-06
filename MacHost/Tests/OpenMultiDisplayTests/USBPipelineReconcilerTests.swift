import XCTest
@testable import OpenMultiDisplay

final class USBPipelineReconcilerTests: XCTestCase {
    func testNoDisconnectedSerialsWhenActiveDevicesAreStillConnected() {
        let result = USBPipelineReconciler.reconcile(
            activeSerials: ["tablet", "phone"],
            connectedSerials: ["tablet", "phone"]
        )

        XCTAssertEqual(result.disconnectedSerials, [])
        XCTAssertEqual(result.remainingSerials, ["phone", "tablet"])
        XCTAssertFalse(result.allPipelinesDisconnected)
    }

    func testFindsOnlyTheDisconnectedSerial() {
        let result = USBPipelineReconciler.reconcile(
            activeSerials: ["tablet", "phone"],
            connectedSerials: ["tablet"]
        )

        XCTAssertEqual(result.disconnectedSerials, ["phone"])
        XCTAssertEqual(result.remainingSerials, ["tablet"])
        XCTAssertFalse(result.allPipelinesDisconnected)
    }

    func testAllPipelinesDisconnectedWhenNoActiveSerialsRemain() {
        let result = USBPipelineReconciler.reconcile(
            activeSerials: ["tablet", "phone"],
            connectedSerials: []
        )

        XCTAssertEqual(result.disconnectedSerials, ["phone", "tablet"])
        XCTAssertEqual(result.remainingSerials, [])
        XCTAssertTrue(result.allPipelinesDisconnected)
    }

    func testIgnoresNewConnectedSerialsThatDoNotHavePipelinesYet() {
        let result = USBPipelineReconciler.reconcile(
            activeSerials: ["tablet"],
            connectedSerials: ["tablet", "new-phone"]
        )

        XCTAssertEqual(result.disconnectedSerials, [])
        XCTAssertEqual(result.remainingSerials, ["tablet"])
    }
}
