package com.openmultidisplay.app

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test

class AuthHandshakeTest {
    @Test
    fun encodesGoldenBytes() {
        val token = ByteArray(AuthHandshake.TOKEN_SIZE_BYTES) { it.toByte() }
        val bytes = AuthHandshake.encodeRequest(token, "iPad Air")
        val expected =
            byteArrayOf(0x53, 0x53, 0x57, 0x41) +
                ByteArray(AuthHandshake.TOKEN_SIZE_BYTES) { it.toByte() } +
                byteArrayOf(8) +
                "iPad Air".toByteArray()
        assertArrayEquals(expected, bytes)
    }

    @Test
    fun rejectsNameLongerThan64() {
        val longName = "x".repeat(AuthHandshake.MAX_DEVICE_NAME_BYTES + 1)

        assertThrows(IllegalArgumentException::class.java) {
            AuthHandshake.encodeRequest(ByteArray(AuthHandshake.TOKEN_SIZE_BYTES), longName)
        }
    }

    @Test
    fun rejectsTokenWrongSize() {
        assertThrows(IllegalArgumentException::class.java) {
            AuthHandshake.encodeRequest(ByteArray(AuthHandshake.TOKEN_SIZE_BYTES - 1), "x")
        }
    }

    @Test
    fun acceptsNameWithExactly64Utf8Bytes() {
        val name = "x".repeat(AuthHandshake.MAX_DEVICE_NAME_BYTES)
        val encoded = AuthHandshake.encodeRequest(ByteArray(AuthHandshake.TOKEN_SIZE_BYTES), name)

        assertEquals(AuthHandshake.REQUEST_FIXED_SIZE_BYTES + AuthHandshake.MAX_DEVICE_NAME_BYTES, encoded.size)
        assertEquals(AuthHandshake.MAX_DEVICE_NAME_BYTES, encoded[AuthHandshake.REQUEST_FIXED_SIZE_BYTES - 1].toInt())
    }

    @Test
    fun rejectsEmptyName() {
        assertThrows(IllegalArgumentException::class.java) {
            AuthHandshake.encodeRequest(ByteArray(AuthHandshake.TOKEN_SIZE_BYTES), "")
        }
    }

    @Test
    fun rejectsUnicodeNameLongerThan64Utf8Bytes() {
        val name = "🙂".repeat(17)

        assertThrows(IllegalArgumentException::class.java) {
            AuthHandshake.encodeRequest(ByteArray(AuthHandshake.TOKEN_SIZE_BYTES), name)
        }
    }

    @Test
    fun parseOKResponse() {
        val r = AuthHandshake.parseResponse(byteArrayOf(0x53, 0x53, 0x57, 0x52, 0x00))
        assertEquals(AuthHandshake.ResponseStatus.OK, r)
    }

    @Test
    fun parseInvalidTokenResponse() {
        val r = AuthHandshake.parseResponse(byteArrayOf(0x53, 0x53, 0x57, 0x52, 0x01))
        assertEquals(AuthHandshake.ResponseStatus.INVALID_TOKEN, r)
    }

    @Test
    fun parseInvalidMagicResponseReturnsNull() {
        val r = AuthHandshake.parseResponse(byteArrayOf(0x58, 0x58, 0x58, 0x58, 0x00))
        assertNull(r)
    }

    @Test
    fun parseTruncatedResponseReturnsNull() {
        val r = AuthHandshake.parseResponse(byteArrayOf(0x53, 0x53, 0x57, 0x52))
        assertNull(r)
    }

    @Test
    fun parseUnknownResponseStatusReturnsNull() {
        val r = AuthHandshake.parseResponse(byteArrayOf(0x53, 0x53, 0x57, 0x52, 0x7F))
        assertNull(r)
    }
}
