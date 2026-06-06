package com.openmultidisplay.app

import org.junit.Assert.assertEquals
import org.junit.Test

class ConnectionModeTest {
    @Test
    fun parsesKnownConnectionModes() {
        assertEquals(ConnectionMode.USB, ConnectionMode.fromName("USB"))
        assertEquals(ConnectionMode.WIRELESS, ConnectionMode.fromName("WIRELESS"))
    }

    @Test
    fun defaultsToUsbForUnknownOrMissingNames() {
        assertEquals(ConnectionMode.USB, ConnectionMode.fromName(null))
        assertEquals(ConnectionMode.USB, ConnectionMode.fromName(""))
        assertEquals(ConnectionMode.USB, ConnectionMode.fromName("bluetooth"))
    }
}
