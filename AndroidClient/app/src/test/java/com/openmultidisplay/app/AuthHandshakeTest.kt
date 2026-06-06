package com.openmultidisplay.app

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test

class AuthHandshakeTest {
    @Test
    fun encodesGoldenBytes() {
        val token = ByteArray(32) { it.toByte() }
        val bytes = AuthHandshake.encodeRequest(token, "iPad Air")
        val expected =
            byteArrayOf(0x53, 0x53, 0x57, 0x41) +
                ByteArray(32) { it.toByte() } +
                byteArrayOf(8) +
                "iPad Air".toByteArray()
        assertArrayEquals(expected, bytes)
    }

    @Test
    fun rejectsNameLongerThan64() {
        val longName = "x".repeat(65)

        assertThrows(IllegalArgumentException::class.java) {
            AuthHandshake.encodeRequest(ByteArray(32), longName)
        }
    }

    @Test
    fun rejectsTokenWrongSize() {
        assertThrows(IllegalArgumentException::class.java) {
            AuthHandshake.encodeRequest(ByteArray(31), "x")
        }
    }

    @Test
    fun acceptsNameWithExactly64Utf8Bytes() {
        val name = "x".repeat(64)
        val encoded = AuthHandshake.encodeRequest(ByteArray(32), name)

        assertEquals(37 + 64, encoded.size)
        assertEquals(64, encoded[36].toInt())
    }

    @Test
    fun rejectsEmptyName() {
        assertThrows(IllegalArgumentException::class.java) {
            AuthHandshake.encodeRequest(ByteArray(32), "")
        }
    }

    @Test
    fun rejectsUnicodeNameLongerThan64Utf8Bytes() {
        val name = "🙂".repeat(17)

        assertThrows(IllegalArgumentException::class.java) {
            AuthHandshake.encodeRequest(ByteArray(32), name)
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
