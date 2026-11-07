package com.zihuagaochn.beatcast.sensor

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.SystemClock

/**
 * Reads the watch's PPG heart-rate sensor directly.
 *
 * A wake-up sensor is preferred so samples keep arriving while the watch is in
 * deep sleep. The service only registers this listener while at least one BLE
 * client is subscribed, which is the single biggest power saving in the app.
 */
class HeartRateSensor(
    context: Context,
    private val onSample: (bpm: Int, contact: Boolean, source: String) -> Unit,
    private val onError: (code: String, detail: String?) -> Unit,
) : SensorEventListener {

    private val sensorManager = context.getSystemService(SensorManager::class.java)
    private var sensor: Sensor? = null
    private var source = SOURCE_UNKNOWN
    private var running = false
    private var lastEmitAt = 0L

    val isRunning: Boolean
        get() = running

    fun start(): Boolean {
        if (running) return true
        val manager = sensorManager
        if (manager == null) {
            onError("sensor_unavailable", "SensorManager is unavailable")
            return false
        }

        val wakeUp = runCatching {
            manager.getDefaultSensor(Sensor.TYPE_HEART_RATE, true)
        }.getOrNull()
        sensor = wakeUp ?: runCatching {
            manager.getDefaultSensor(Sensor.TYPE_HEART_RATE)
        }.getOrNull()
        source = if (wakeUp != null) SOURCE_WAKE_UP else SOURCE_STANDARD

        val selected = sensor
        if (selected == null) {
            onError("sensor_unavailable", "No TYPE_HEART_RATE sensor on this watch")
            return false
        }

        running = try {
            manager.registerListener(
                this,
                selected,
                SAMPLE_PERIOD_US,
                0,
            )
        } catch (security: SecurityException) {
            onError("sensor_permission", security.message)
            false
        } catch (error: RuntimeException) {
            onError("sensor_register_failed", error.message)
            false
        }

        if (!running) {
            onError("sensor_register_failed", "registerListener returned false")
        }
        return running
    }

    fun stop() {
        if (!running) return
        running = false
        runCatching { sensorManager?.unregisterListener(this) }
        sensor = null
        source = SOURCE_UNKNOWN
        lastEmitAt = 0L
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (!running || event.sensor.type != Sensor.TYPE_HEART_RATE) return
        val now = SystemClock.elapsedRealtime()
        if (now - lastEmitAt < MIN_EMIT_INTERVAL_MS) return

        val bpm = event.values.firstOrNull()?.toInt() ?: return
        lastEmitAt = now
        if (bpm <= 0) {
            // Keep the GATT characteristic honest: 0 means "no reading",
            // instead of leaving a stale BPM on the strap.
            onSample(0, false, source)
            return
        }
        val contact = event.accuracy != SensorManager.SENSOR_STATUS_UNRELIABLE
        onSample(bpm.coerceIn(20, 255), contact, source)
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // Accuracy changes are folded into each sample's contact flag. No
        // additional work is needed here.
    }

    companion object {
        const val SOURCE_WAKE_UP = "raw_wakeup"
        const val SOURCE_STANDARD = "raw"
        const val SOURCE_UNKNOWN = "unknown"

        private const val SAMPLE_PERIOD_US = 1_000_000
        private const val MIN_EMIT_INTERVAL_MS = 900L
    }
}
