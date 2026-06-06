package com.openmultidisplay.app

import java.net.URI
import java.net.URLDecoder
import java.nio.charset.StandardCharsets
import java.util.Base64

object PairingURL {
    data class Parsed(val host: String, val port: Int, val token: ByteArray, val macName: String)

    fun parse(url: String): Parsed? {
        val uri =
            try {
                URI(url)
            } catch (e: Exception) {
                return null
            }
        if (uri.scheme != "openmultidisplay") return null
        val host = uri.host ?: return null
        val port = uri.port.takeIf { it in 1..65535 } ?: return null
        val queryParams = parseQuery(uri.rawQuery ?: return null)
        val tokenB64 = queryParams["t"] ?: return null
        val token =
            try {
                Base64.getUrlDecoder().decode(withBase64Padding(tokenB64))
            } catch (e: IllegalArgumentException) {
                return null
            }
        if (token.size != 32) return null
        val name = queryParams["name"] ?: "Mac"
        return Parsed(host, port, token, name)
    }

    private fun parseQuery(rawQuery: String): Map<String, String> =
        rawQuery
            .split("&")
            .filter { it.isNotEmpty() }
            .mapNotNull { part ->
                val separatorIndex = part.indexOf("=")
                if (separatorIndex < 0) return@mapNotNull null
                val key = decode(part.substring(0, separatorIndex))
                val value = decode(part.substring(separatorIndex + 1))
                key to value
            }
            .toMap()

    private fun decode(value: String): String = URLDecoder.decode(value, StandardCharsets.UTF_8.name())

    private fun withBase64Padding(value: String): String {
        val paddingLength = (4 - value.length % 4) % 4
        return value + "=".repeat(paddingLength)
    }
}
