package com.zihuagaochn.beatcast.model

/**
 * Encoder for the Bluetooth SIG Heart Rate Measurement characteristic (0x2A37).
 *
 * Flags:
 *   bit 0: value format (0 = uint8, 1 = uint16)
 *   bit 1: sensor contact detected
 *   bit 2: sensor contact supported
 *
 * BeatCast only needs the uint8 BPM field. Keeping the payload at two bytes
 * means it fits in the default 23-byte ATT MTU and costs 2 bytes per second on
 * air.
 */
object HeartRateMeasurement {
    const val FLAG_UINT16 = 0x01
    const val FLAG_CONTACT_DETECTED = 0x02
    const val FLAG_CONTACT_SUPPORTED = 0x04

    fun encode(bpm: Int, contactDetected: Boolean): ByteArray {
        val value = bpm.coerceIn(0, 255)
        var flags = FLAG_CONTACT_SUPPORTED
        if (contactDetected && value > 0) {
            flags = flags or FLAG_CONTACT_DETECTED
        }
        return byteArrayOf(flags.toByte(), value.toByte())
    }

    /** Historical default payload: contact supported but no heartbeat yet. */
    fun empty(): ByteArray = encode(0, false)
}
