import XCTest
@testable import OpenMultiDisplay

final class WireCodecTests: XCTestCase {
    func testDisplayConfigPacketUsesBigEndianIntegers() {
        let packet = WireCodec.displayConfigPacket(width: 1920, height: 1200, rotation: 270)

        XCTAssertEqual(
            Array(packet),
            [
                1,
                0x00, 0x00, 0x07, 0x80,
                0x00, 0x00, 0x04, 0xB0,
                0x00, 0x00, 0x01, 0x0E
            ]
        )
    }

    func testLegacyVideoFramePacketKeepsOriginalWireFormat() {
        let payload = Data([0xAA, 0xBB, 0xCC])
        let packet = WireCodec.videoFramePacket(
            payload: payload,
            timestamp: 0x0102_0304_0506_0708,
            isKeyframe: true,
            clientSupportsFrameMetadata: false
        )

        XCTAssertEqual(Array(packet), [0, 0, 0, 0, 3, 0xAA, 0xBB, 0xCC])
    }

    func testMetadataVideoFramePacketIncludesFlagsAndTimestamp() {
        let payload = Data([0x11, 0x22])
        let packet = WireCodec.videoFramePacket(
            payload: payload,
            timestamp: 0x0102_0304_0506_0708,
            isKeyframe: true,
            clientSupportsFrameMetadata: true
        )

        XCTAssertEqual(
            Array(packet),
            [
                6,
                0x00, 0x00, 0x00, 0x02,
                0x01,
                0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
                0x11, 0x22
            ]
        )
    }

    func testPongPacketEchoesClientTimestampBytes() {
        let timestamp = Data([1, 2, 3, 4, 5, 6, 7, 8])

        XCTAssertEqual(Array(WireCodec.pongPacket(clientTimestamp: timestamp)), [5, 1, 2, 3, 4, 5, 6, 7, 8])
    }

    func testParsesSinglePointerTouchEvent() throws {
        let packet = Data([
            2, 1,
            0x00, 0x00, 0xC0, 0x3F, // 1.5
            0x00, 0x00, 0x10, 0xC0, // -2.25
            0x05, 0x00, 0x00, 0x00
        ])

        let event = try XCTUnwrap(WireCodec.parseTouchEvent(packet))

        XCTAssertEqual(event.x1, 1.5, accuracy: 0.0001)
        XCTAssertEqual(event.y1, -2.25, accuracy: 0.0001)
        XCTAssertEqual(event.action, 5)
        XCTAssertEqual(event.pointerCount, 1)
        XCTAssertEqual(event.x2, 0)
        XCTAssertEqual(event.y2, 0)
    }

    func testParsesTwoPointerTouchEvent() throws {
        let packet = Data([
            2, 2,
            0x00, 0x00, 0x80, 0x3F, // 1.0
            0x00, 0x00, 0x00, 0x40, // 2.0
            0x00, 0x00, 0x40, 0x40, // 3.0
            0x00, 0x00, 0x80, 0x40, // 4.0
            0x02, 0x00, 0x00, 0x00
        ])

        let event = try XCTUnwrap(WireCodec.parseTouchEvent(packet))

        XCTAssertEqual(event.x1, 1.0, accuracy: 0.0001)
        XCTAssertEqual(event.y1, 2.0, accuracy: 0.0001)
        XCTAssertEqual(event.x2, 3.0, accuracy: 0.0001)
        XCTAssertEqual(event.y2, 4.0, accuracy: 0.0001)
        XCTAssertEqual(event.action, 2)
        XCTAssertEqual(event.pointerCount, 2)
    }

    func testRejectsMalformedTouchEvents() {
        XCTAssertNil(WireCodec.parseTouchEvent(Data([2])))
        XCTAssertNil(WireCodec.parseTouchEvent(Data([2, 3, 0, 0, 0, 0])))
        XCTAssertNil(WireCodec.parseTouchEvent(Data([9, 1, 0, 0, 0, 0])))
    }

    func testKeyframeRequestFlagParsing() {
        XCTAssertEqual(WireCodec.keyframeRequestIsForced(Data([7, 0])), false)
        XCTAssertEqual(WireCodec.keyframeRequestIsForced(Data([7, 1])), true)
        XCTAssertNil(WireCodec.keyframeRequestIsForced(Data([7])))
        XCTAssertNil(WireCodec.keyframeRequestIsForced(Data([8, 1])))
    }
}
