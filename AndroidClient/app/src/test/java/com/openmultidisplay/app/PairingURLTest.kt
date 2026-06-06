package com.openmultidisplay.app

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.util.Base64

class PairingURLTest {
    @Test
    fun parsesValidOpenMultiDisplayUrl() {
        val token = ByteArray(32) { it.toByte() }
        val url = buildUrl(token, host = "192.168.1.10", port = 54321, name = "MacBook Pro")

        val parsed = PairingURL.parse(url)

        assertEquals("192.168.1.10", parsed?.host)
        assertEquals(54321, parsed?.port)
        assertArrayEquals(token, parsed?.token)
        assertEquals("MacBook Pro", parsed?.macName)
    }

    @Test
    fun defaultsNameWhenMissing() {
        val token = ByteArray(32) { (it + 1).toByte() }
        val tokenText = Base64.getUrlEncoder().withoutPadding().encodeToString(token)

        val parsed = PairingURL.parse("openmultidisplay://mac.local:1234?t=$tokenText")

        assertEquals("Mac", parsed?.macName)
    }

    @Test
    fun acceptsPaddedUrlSafeToken() {
        val token = ByteArray(32) { 7 }
        val tokenText = Base64.getUrlEncoder().encodeToString(token)

        val parsed = PairingURL.parse("openmultidisplay://mac.local:1234?t=$tokenText")

        assertArrayEquals(token, parsed?.token)
    }

    @Test
    fun rejectsWrongScheme() {
        val token = Base64.getUrlEncoder().withoutPadding().encodeToString(ByteArray(32))

        assertNull(PairingURL.parse("https://mac.local:1234?t=$token"))
    }

    @Test
    fun rejectsMissingHost() {
        val token = Base64.getUrlEncoder().withoutPadding().encodeToString(ByteArray(32))

        assertNull(PairingURL.parse("openmultidisplay://:1234?t=$token"))
    }

    @Test
    fun rejectsInvalidPort() {
        val token = Base64.getUrlEncoder().withoutPadding().encodeToString(ByteArray(32))

        assertNull(PairingURL.parse("openmultidisplay://mac.local:0?t=$token"))
        assertNull(PairingURL.parse("openmultidisplay://mac.local:65536?t=$token"))
    }

    @Test
    fun rejectsMissingToken() {
        assertNull(PairingURL.parse("openmultidisplay://mac.local:1234?name=Mac"))
    }

    @Test
    fun rejectsTokenWithWrongDecodedLength() {
        val token = Base64.getUrlEncoder().withoutPadding().encodeToString(ByteArray(31))

        assertNull(PairingURL.parse("openmultidisplay://mac.local:1234?t=$token"))
    }

    private fun buildUrl(
        token: ByteArray,
        host: String,
        port: Int,
        name: String,
    ): String {
        val tokenText = Base64.getUrlEncoder().withoutPadding().encodeToString(token)
        val nameText = URLEncoder.encode(name, StandardCharsets.UTF_8.name())
        return "openmultidisplay://$host:$port?t=$tokenText&name=$nameText"
    }
}
