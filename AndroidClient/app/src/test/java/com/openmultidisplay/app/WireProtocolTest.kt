package com.openmultidisplay.app

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class WireProtocolTest {
    @Test
    fun encodesMetadataSupportCapability() {
        assertArrayEquals(
            byteArrayOf(WireProtocol.MESSAGE_CLIENT_SUPPORTS_FRAME_METADATA.toByte()),
            WireProtocol.encodeClientMetadataSupport(),
        )
    }

    @Test
    fun encodesSinglePointerTouchInLittleEndianFormat() {
        val packet =
            WireProtocol.encodeTouch(
                x = 1.5f,
                y = -2.25f,
                action = 5,
                pointerCount = 1,
            )

        assertArrayEquals(
            byteArrayOf(
                2, 1,
                0x00, 0x00, 0xC0.toByte(), 0x3F,
                0x00, 0x00, 0x10, 0xC0.toByte(),
                0x05, 0x00, 0x00, 0x00,
            ),
            packet,
        )
    }

    @Test
    fun encodesTwoPointerTouchInLittleEndianFormat() {
        val packet =
            WireProtocol.encodeTouch(
                x = 1f,
                y = 2f,
                action = 2,
                pointerCount = 2,
                x2 = 3f,
                y2 = 4f,
            )

        assertArrayEquals(
            byteArrayOf(
                2, 2,
                0x00, 0x00, 0x80.toByte(), 0x3F,
                0x00, 0x00, 0x00, 0x40,
                0x00, 0x00, 0x40, 0x40,
                0x00, 0x00, 0x80.toByte(), 0x40,
                0x02, 0x00, 0x00, 0x00,
            ),
            packet,
        )
    }

    @Test
    fun clampsTouchPointerCountToSupportedRange() {
        assertEquals(14, WireProtocol.encodeTouch(1f, 2f, action = 0, pointerCount = 0).size)
        assertEquals(22, WireProtocol.encodeTouch(1f, 2f, action = 0, pointerCount = 5).size)
    }

    @Test
    fun encodesKeyframeRequests() {
        assertArrayEquals(byteArrayOf(7, 0), WireProtocol.encodeKeyframeRequest(force = false))
        assertArrayEquals(byteArrayOf(7, 1), WireProtocol.encodeKeyframeRequest(force = true))
    }

    @Test
    fun encodesPingWithLittleEndianTimestamp() {
        val packet = WireProtocol.encodePing(0x0102_0304_0506_0708L)

        assertArrayEquals(
            byteArrayOf(4, 0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01),
            packet,
        )
    }

    @Test
    fun parsesHostDisplayConfigPacket() {
        val packet =
            byteArrayOf(
                1,
                0x00, 0x00, 0x07, 0x80.toByte(),
                0x00, 0x00, 0x04, 0xB0.toByte(),
                0x00, 0x00, 0x01, 0x0E,
            )

        val config = WireProtocol.parseDisplayConfigPacket(packet)

        assertEquals(1920, config?.width)
        assertEquals(1200, config?.height)
        assertEquals(270, config?.rotation)
    }

    @Test
    fun rejectsMalformedDisplayConfigPacket() {
        assertNull(WireProtocol.parseDisplayConfigPacket(byteArrayOf(1, 0, 0)))
        assertNull(WireProtocol.parseDisplayConfigPacket(ByteArray(WireProtocol.DISPLAY_CONFIG_PACKET_SIZE) { 9 }))
    }

    @Test
    fun parsesMetadataFrameHeader() {
        val header =
            byteArrayOf(
                6,
                0x00, 0x00, 0x00, 0x02,
                0x01,
                0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
            )

        val parsed = WireProtocol.parseMetadataFrameHeader(header)

        assertEquals(2, parsed?.frameSize)
        assertEquals(true, parsed?.isKeyframe)
        assertEquals(0x0102_0304_0506_0708L, parsed?.captureTimestampNanos)
    }

    @Test
    fun rejectsMalformedMetadataFrameHeader() {
        assertNull(WireProtocol.parseMetadataFrameHeader(byteArrayOf(6, 0, 0)))
        assertNull(WireProtocol.parseMetadataFrameHeader(ByteArray(WireProtocol.METADATA_FRAME_HEADER_SIZE) { 0 }))
    }
}
