package com.zihuagaochn.beatcast.model

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Test

class HeartRateMeasurementTest {
    @Test
    fun encodesUint8HeartRateWithContact() {
        val payload = HeartRateMeasurement.encode(72, contactDetected = true)
        assertArrayEquals(byteArrayOf(0x06, 72), payload)
        assertEquals(2, payload.size)
    }

    @Test
    fun clearsContactBitWhenThereIsNoContact() {
        val payload = HeartRateMeasurement.encode(80, contactDetected = false)
        assertArrayEquals(byteArrayOf(0x04, 80), payload)
    }

    @Test
    fun clampsToTheBluetoothUint8Range() {
        assertArrayEquals(
            byteArrayOf(0x04, 0),
            HeartRateMeasurement.encode(0, contactDetected = true),
        )
        assertArrayEquals(
            byteArrayOf(0x06, 0xFF.toByte()),
            HeartRateMeasurement.encode(300, contactDetected = true),
        )
    }

    @Test
    fun emptyPayloadHasNoContact() {
        assertArrayEquals(byteArrayOf(0x04, 0), HeartRateMeasurement.empty())
    }
}
