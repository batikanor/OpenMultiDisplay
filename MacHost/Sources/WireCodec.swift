import Foundation

enum WireMessageType {
    static let legacyVideoFrame: UInt8 = 0
    static let displayConfig: UInt8 = 1
    static let touchEvent: UInt8 = 2
    static let ping: UInt8 = 4
    static let pong: UInt8 = 5
    static let videoFrameWithMetadata: UInt8 = 6
    static let keyframeRequest: UInt8 = 7
    static let clientSupportsFrameMetadata: UInt8 = 8
}

struct TouchWireEvent: Equatable {
    let x1: Float
    let y1: Float
    let action: Int
    let pointerCount: Int
    let x2: Float
    let y2: Float
}

enum WireCodec {
    static let keyframeRequestFlagForce: UInt8 = 1

    static func displayConfigPacket(width: Int, height: Int, rotation: Int) -> Data {
        var packet = Data(capacity: 13)
        packet.append(WireMessageType.displayConfig)
        appendInt32BigEndian(width, to: &packet)
        appendInt32BigEndian(height, to: &packet)
        appendInt32BigEndian(rotation, to: &packet)
        return packet
    }

    static func videoFramePacket(
        payload: Data,
        timestamp: UInt64,
        isKeyframe: Bool,
        clientSupportsFrameMetadata: Bool
    ) -> Data {
        if clientSupportsFrameMetadata {
            return metadataVideoFramePacket(payload: payload, timestamp: timestamp, isKeyframe: isKeyframe)
        }
        return legacyVideoFramePacket(payload: payload)
    }

    static func legacyVideoFramePacket(payload: Data) -> Data {
        var packet = Data(capacity: payload.count + 5)
        packet.append(WireMessageType.legacyVideoFrame)
        appendInt32BigEndian(payload.count, to: &packet)
        packet.append(payload)
        return packet
    }

    static func metadataVideoFramePacket(payload: Data, timestamp: UInt64, isKeyframe: Bool) -> Data {
        var packet = Data(capacity: payload.count + 14)
        packet.append(WireMessageType.videoFrameWithMetadata)
        appendInt32BigEndian(payload.count, to: &packet)
        packet.append(isKeyframe ? 1 : 0)
        appendUInt64BigEndian(timestamp, to: &packet)
        packet.append(payload)
        return packet
    }

    static func pongPacket(clientTimestamp: Data) -> Data {
        precondition(clientTimestamp.count == 8, "pong timestamp must be exactly 8 bytes")
        var packet = Data(capacity: 9)
        packet.append(WireMessageType.pong)
        packet.append(clientTimestamp)
        return packet
    }

    static func touchEventLength(pointerCount: Int) -> Int? {
        guard pointerCount == 1 || pointerCount == 2 else { return nil }
        return 2 + pointerCount * 8 + 4
    }

    static func parseTouchEvent(_ packet: Data) -> TouchWireEvent? {
        guard packet.count >= 2,
              byte(in: packet, at: 0) == WireMessageType.touchEvent else {
            return nil
        }

        let pointerCount = Int(byte(in: packet, at: 1))
        guard let expectedLength = touchEventLength(pointerCount: pointerCount),
              packet.count >= expectedLength,
              let x1 = littleEndianFloat(in: packet, at: 2),
              let y1 = littleEndianFloat(in: packet, at: 6),
              let action = littleEndianInt32(in: packet, at: 2 + pointerCount * 8) else {
            return nil
        }

        let x2 = pointerCount == 2 ? littleEndianFloat(in: packet, at: 10) ?? 0 : 0
        let y2 = pointerCount == 2 ? littleEndianFloat(in: packet, at: 14) ?? 0 : 0

        return TouchWireEvent(
            x1: x1,
            y1: y1,
            action: Int(action),
            pointerCount: pointerCount,
            x2: x2,
            y2: y2
        )
    }

    static func keyframeRequestIsForced(_ packet: Data) -> Bool? {
        guard packet.count >= 2,
              byte(in: packet, at: 0) == WireMessageType.keyframeRequest else {
            return nil
        }
        return (byte(in: packet, at: 1) & keyframeRequestFlagForce) != 0
    }

    private static func appendInt32BigEndian(_ value: Int, to data: inout Data) {
        var bigEndianValue = Int32(value).bigEndian
        withUnsafeBytes(of: &bigEndianValue) { data.append(contentsOf: $0) }
    }

    private static func appendUInt64BigEndian(_ value: UInt64, to data: inout Data) {
        var bigEndianValue = value.bigEndian
        withUnsafeBytes(of: &bigEndianValue) { data.append(contentsOf: $0) }
    }

    private static func littleEndianFloat(in data: Data, at offset: Int) -> Float? {
        littleEndianUInt32(in: data, at: offset).map { Float(bitPattern: $0) }
    }

    private static func littleEndianInt32(in data: Data, at offset: Int) -> Int32? {
        littleEndianUInt32(in: data, at: offset).map { Int32(bitPattern: $0) }
    }

    private static func littleEndianUInt32(in data: Data, at offset: Int) -> UInt32? {
        guard data.count >= offset + 4 else { return nil }
        return UInt32(byte(in: data, at: offset)) |
            UInt32(byte(in: data, at: offset + 1)) << 8 |
            UInt32(byte(in: data, at: offset + 2)) << 16 |
            UInt32(byte(in: data, at: offset + 3)) << 24
    }

    private static func byte(in data: Data, at offset: Int) -> UInt8 {
        data[data.index(data.startIndex, offsetBy: offset)]
    }
}
