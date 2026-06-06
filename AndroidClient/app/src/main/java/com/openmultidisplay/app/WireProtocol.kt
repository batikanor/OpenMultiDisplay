package com.openmultidisplay.app

import java.nio.ByteBuffer
import java.nio.ByteOrder

object WireProtocol {
    const val MESSAGE_VIDEO_FRAME = 0
    const val MESSAGE_DISPLAY_CONFIG = 1
    const val MESSAGE_TOUCH_EVENT = 2
    const val MESSAGE_PING = 4
    const val MESSAGE_PONG = 5
    const val MESSAGE_VIDEO_FRAME_WITH_METADATA = 6
    const val MESSAGE_KEYFRAME_REQUEST = 7
    const val MESSAGE_CLIENT_SUPPORTS_FRAME_METADATA = 8

    const val FRAME_FLAG_KEYFRAME = 1
    const val DISPLAY_CONFIG_PACKET_SIZE = 13
    const val METADATA_FRAME_HEADER_SIZE = 14
    const val PING_PACKET_SIZE = 9
    const val PONG_TIMESTAMP_SIZE_BYTES = 8
    private const val KEYFRAME_REQUEST_FLAG_FORCE = 1

    data class DisplayConfig(
        val width: Int,
        val height: Int,
        val rotation: Int,
    )

    data class MetadataFrameHeader(
        val frameSize: Int,
        val isKeyframe: Boolean,
        val captureTimestampNanos: Long,
    )

    fun encodeClientMetadataSupport(): ByteArray = byteArrayOf(MESSAGE_CLIENT_SUPPORTS_FRAME_METADATA.toByte())

    fun encodeTouch(
        x: Float,
        y: Float,
        action: Int,
        pointerCount: Int = 1,
        x2: Float = 0f,
        y2: Float = 0f,
    ): ByteArray {
        val count = pointerCount.coerceIn(1, 2)
        val packetSize = 6 + count * 8
        val buffer = ByteBuffer.allocate(packetSize).order(ByteOrder.LITTLE_ENDIAN)
        buffer.put(MESSAGE_TOUCH_EVENT.toByte())
        buffer.put(count.toByte())
        buffer.putFloat(x)
        buffer.putFloat(y)
        if (count == 2) {
            buffer.putFloat(x2)
            buffer.putFloat(y2)
        }
        buffer.putInt(action)
        return buffer.array()
    }

    fun encodeKeyframeRequest(force: Boolean): ByteArray {
        val flags = if (force) KEYFRAME_REQUEST_FLAG_FORCE else 0
        return byteArrayOf(MESSAGE_KEYFRAME_REQUEST.toByte(), flags.toByte())
    }

    fun encodePing(timestampNanos: Long): ByteArray {
        val buffer = ByteBuffer.allocate(PING_PACKET_SIZE).order(ByteOrder.LITTLE_ENDIAN)
        buffer.put(MESSAGE_PING.toByte())
        buffer.putLong(timestampNanos)
        return buffer.array()
    }

    fun parseDisplayConfigPacket(packet: ByteArray): DisplayConfig? {
        if (packet.size != DISPLAY_CONFIG_PACKET_SIZE || packet[0].toInt() != MESSAGE_DISPLAY_CONFIG) return null
        val buffer = ByteBuffer.wrap(packet, 1, 12).order(ByteOrder.BIG_ENDIAN)
        return DisplayConfig(
            width = buffer.int,
            height = buffer.int,
            rotation = buffer.int,
        )
    }

    fun parseMetadataFrameHeader(packetHeader: ByteArray): MetadataFrameHeader? {
        if (
            packetHeader.size != METADATA_FRAME_HEADER_SIZE ||
            packetHeader[0].toInt() != MESSAGE_VIDEO_FRAME_WITH_METADATA
        ) {
            return null
        }
        val buffer = ByteBuffer.wrap(packetHeader).order(ByteOrder.BIG_ENDIAN)
        buffer.get()
        val frameSize = buffer.int
        val flags = buffer.get().toInt()
        return MetadataFrameHeader(
            frameSize = frameSize,
            isKeyframe = (flags and FRAME_FLAG_KEYFRAME) != 0,
            captureTimestampNanos = buffer.long,
        )
    }
}
