package com.zihuagaochn.beatcast.model

/**
 * User-tunable power settings. Values are persisted as primitives so the
 * service can be restarted by the OS without a Flutter engine.
 */
data class BroadcastSettings(
    val advertisingMode: String = MODE_BALANCED,
    val autoStopMinutes: Int = 15,
    val maxSessionMinutes: Int = 0,
) {
    companion object {
        const val MODE_BALANCED = "balanced"
        const val MODE_LOW_POWER = "low_power"

        val DEFAULTS = BroadcastSettings()

        fun sanitize(
            mode: String?,
            autoStop: Int?,
            maxSession: Int?,
        ): BroadcastSettings = BroadcastSettings(
            advertisingMode = if (mode == MODE_LOW_POWER) MODE_LOW_POWER else MODE_BALANCED,
            autoStopMinutes = autoStop?.takeIf { it in setOf(0, 5, 15, 30) } ?: 15,
            maxSessionMinutes = maxSession?.takeIf { it in setOf(0, 60, 120, 240) } ?: 0,
        )
    }

    fun toMap(): Map<String, Any> = mapOf(
        "advertisingMode" to advertisingMode,
        "autoStopMinutes" to autoStopMinutes,
        "maxSessionMinutes" to maxSessionMinutes,
    )
}

/**
 * A single immutable view of the broadcast. It is safe to hand to the UI from
 * any thread; every consumer receives a copy through [toMap].
 */
data class BroadcastSnapshot(
    val phase: String = PHASE_IDLE,
    val serviceRunning: Boolean = false,
    val bpm: Int? = null,
    val contact: Boolean = false,
    val clients: Int = 0,
    val advertising: Boolean = false,
    val errorCode: String? = null,
    val errorDetail: String? = null,
    val deviceName: String = "Wear OS watch",
    val batteryPercent: Int? = null,
    val startedAtEpochMs: Long? = null,
    val lastSampleAtEpochMs: Long? = null,
    val sensorSource: String? = null,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "phase" to phase,
        "serviceRunning" to serviceRunning,
        "bpm" to bpm,
        "contact" to contact,
        "clients" to clients,
        "advertising" to advertising,
        "errorCode" to errorCode,
        "errorDetail" to errorDetail,
        "deviceName" to deviceName,
        "batteryPercent" to batteryPercent,
        "startedAtEpochMs" to startedAtEpochMs,
        "lastSampleAtEpochMs" to lastSampleAtEpochMs,
        "sensorSource" to sensorSource,
    )

    companion object {
        const val PHASE_IDLE = "idle"
        const val PHASE_STARTING = "starting"
        const val PHASE_ADVERTISING = "advertising"
        const val PHASE_LIVE = "live"
        const val PHASE_ERROR = "error"
    }
}
