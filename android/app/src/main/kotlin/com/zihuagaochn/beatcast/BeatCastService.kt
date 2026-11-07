package com.zihuagaochn.beatcast

import android.app.Service
import android.bluetooth.BluetoothAdapter
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import com.zihuagaochn.beatcast.ble.BleBroadcaster
import com.zihuagaochn.beatcast.core.BroadcastStateStore
import com.zihuagaochn.beatcast.core.NotificationFactory
import com.zihuagaochn.beatcast.core.Permissions
import com.zihuagaochn.beatcast.core.SettingsStore
import com.zihuagaochn.beatcast.model.BroadcastSettings
import com.zihuagaochn.beatcast.model.BroadcastSnapshot
import com.zihuagaochn.beatcast.sensor.HeartRateSensor

/**
 * The long-lived owner of the broadcast. Keeping the sensor and BLE stack in a
 * native foreground service means the feature survives the Flutter activity
 * being backgrounded, the screen turning off, or the UI process being torn
 * down independently.
 */
class BeatCastService : Service(), BleBroadcaster.Listener {

    private lateinit var settingsStore: SettingsStore
    private lateinit var notifications: NotificationFactory
    private lateinit var powerManager: PowerManager

    private var settings = BroadcastSettings.DEFAULTS
    private var ble: BleBroadcaster? = null
    private var sensor: HeartRateSensor? = null
    private var wakeLock: PowerManager.WakeLock? = null

    private val mainHandler = Handler(Looper.getMainLooper())
    private var running = false
    private var shuttingDown = false
    private var startedAt = 0L
    private var idleSince: Long? = null
    private var lastNotificationAt = 0L
    private var lastBatteryPercent: Int? = null
    private var receiverRegistered = false
    private var lastBpm: Int? = null
    private var lastContact = false
    private var lastBleSentAt = 0L
    private var subscriberCount = 0

    private val bleTick = object : Runnable {
        override fun run() {
            if (!running || sensor?.isRunning != true || subscriberCount == 0) return
            val bpm = lastBpm
            val now = SystemClock.elapsedRealtime()
            if (bpm != null && now - lastBleSentAt >= BLE_HEARTBEAT_MS) {
                lastBleSentAt = now
                ble?.updateMeasurement(bpm, lastContact)
            }
            mainHandler.postDelayed(this, BLE_HEARTBEAT_MS)
        }
    }

    private val tick = object : Runnable {
        override fun run() {
            if (!running) return
            refreshBattery()
            enforcePowerLimits()
            updateNotification()
            mainHandler.postDelayed(this, TICK_INTERVAL_MS)
        }
    }

    private val bluetoothReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != BluetoothAdapter.ACTION_STATE_CHANGED) return
            when (intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR)) {
                BluetoothAdapter.STATE_OFF, BluetoothAdapter.STATE_TURNING_OFF -> {
                    if (running) {
                        failAndStop("bluetooth_off", "Bluetooth was turned off")
                    }
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        settingsStore = SettingsStore(this)
        settings = settingsStore.load()
        notifications = NotificationFactory(this)
        notifications.ensureChannel()
        powerManager = getSystemService(PowerManager::class.java)
        registerBluetoothReceiver()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopBroadcast()
                return START_NOT_STICKY
            }

            ACTION_UPDATE -> {
                if (!running) {
                    stopSelf()
                    return START_NOT_STICKY
                }
                val previous = settings
                settings = settingsStore.load()
                if (previous.advertisingMode != settings.advertisingMode) {
                    ble?.restartAdvertising(settings)
                }
                updateNotification(force = true)
                return START_STICKY
            }
        }

        if (!running) {
            startBroadcast()
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        teardown(clearState = !shuttingDown)
        super.onDestroy()
    }

    private fun startBroadcast() {
        if (running) return
        subscriberCount = 0
        val missing = Permissions.missingForStart(this)
        if (missing.isNotEmpty()) {
            // Do not start a foreground service we cannot legally feed.
            shuttingDown = true
            BroadcastStateStore.update {
                it.copy(
                    phase = BroadcastSnapshot.PHASE_ERROR,
                    serviceRunning = false,
                    errorCode = "permissions_revoked",
                    errorDetail = missing.joinToString(","),
                )
            }
            stopSelf()
            return
        }

        running = true
        shuttingDown = false
        startedAt = System.currentTimeMillis()
        idleSince = System.currentTimeMillis()
        lastNotificationAt = 0L

        val starting = BroadcastStateStore.snapshot.copy(
            phase = BroadcastSnapshot.PHASE_STARTING,
            serviceRunning = true,
            bpm = null,
            clients = 0,
            advertising = false,
            errorCode = null,
            errorDetail = null,
            deviceName = ble?.advertisedName() ?: "Wear OS watch",
            batteryPercent = lastBatteryPercent,
            startedAtEpochMs = startedAt,
            lastSampleAtEpochMs = null,
            sensorSource = null,
        )
        BroadcastStateStore.update { starting }
        refreshBattery()

        // Promote immediately. Android requires this within a few seconds of
        // startForegroundService, and Wear OS will kill an unpromoted service.
        try {
            startForegroundCompat(notifications.build(BroadcastStateStore.snapshot))
        } catch (error: SecurityException) {
            shuttingDown = true
            BroadcastStateStore.update {
                it.copy(
                    phase = BroadcastSnapshot.PHASE_ERROR,
                    serviceRunning = false,
                    errorCode = "foreground_start_failed",
                    errorDetail = error.message,
                )
            }
            stopSelf()
            return
        } catch (error: RuntimeException) {
            shuttingDown = true
            BroadcastStateStore.update {
                it.copy(
                    phase = BroadcastSnapshot.PHASE_ERROR,
                    serviceRunning = false,
                    errorCode = "foreground_start_failed",
                    errorDetail = error.message,
                )
            }
            stopSelf()
            return
        }

        registerBluetoothReceiver()
        ble = BleBroadcaster(this, this).also { it.start(settings) }
        mainHandler.removeCallbacks(tick)
        mainHandler.postDelayed(tick, TICK_INTERVAL_MS)
    }

    private fun startForegroundCompat(notification: android.app.Notification) {
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(
                NotificationFactory.NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH or
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE,
            )
        } else {
            startForeground(
                NotificationFactory.NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE,
            )
        }
    }

    private fun stopBroadcast() {
        shuttingDown = false
        teardown(clearState = true)
        stopSelf()
    }

    private fun failAndStop(code: String, detail: String?) {
        if (shuttingDown) return
        shuttingDown = true
        stopSensor()
        mainHandler.removeCallbacks(tick)
        BroadcastStateStore.update {
            it.copy(
                phase = BroadcastSnapshot.PHASE_ERROR,
                serviceRunning = false,
                bpm = null,
                clients = 0,
                advertising = false,
                errorCode = code,
                errorDetail = detail,
                lastSampleAtEpochMs = null,
                sensorSource = null,
            )
        }
        updateNotification(force = true)
        mainHandler.postDelayed({
            releaseResources()
            stopForegroundCompat()
            stopSelf()
        }, ERROR_HOLD_MS)
    }

    private fun teardown(clearState: Boolean) {
        shuttingDown = true
        running = false
        mainHandler.removeCallbacks(tick)
        mainHandler.removeCallbacks(bleTick)
        stopSensor()
        releaseResources()
        if (clearState) {
            BroadcastStateStore.update {
                it.copy(
                    phase = BroadcastSnapshot.PHASE_IDLE,
                    serviceRunning = false,
                    bpm = null,
                    contact = false,
                    clients = 0,
                    advertising = false,
                    errorCode = null,
                    errorDetail = null,
                    startedAtEpochMs = null,
                    lastSampleAtEpochMs = null,
                    sensorSource = null,
                )
            }
        }
        stopForegroundCompat()
    }

    private fun releaseResources() {
        ble?.stop()
        ble = null
        releaseWakeLock()
        unregisterBluetoothReceiver()
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= 24) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    private fun startSensor() {
        if (sensor?.isRunning == true) return
        acquireWakeLock()
        val reader = HeartRateSensor(
            context = this,
            onSample = ::onHeartRateSample,
            onError = { code, detail ->
                failAndStop(code, detail)
            },
        )
        sensor = reader
        if (!reader.start()) {
            // onError above normally handles this; keep a guard for stacks that
            // return false without invoking the callback.
            if (running) failAndStop("sensor_unavailable", "Heart rate sensor did not start")
            return
        }
        updateState {
            it.copy(
                phase = if (it.clients > 0) BroadcastSnapshot.PHASE_LIVE else it.phase,
                errorCode = null,
                errorDetail = null,
                sensorSource = if (it.sensorSource == null) "raw" else it.sensorSource,
            )
        }
        if (subscriberCount > 0) {
            mainHandler.removeCallbacks(bleTick)
            mainHandler.postDelayed(bleTick, BLE_HEARTBEAT_MS)
        }
    }

    private fun stopSensor() {
        sensor?.stop()
        sensor = null
        lastBpm = null
        lastContact = false
        subscriberCount = 0
        mainHandler.removeCallbacks(bleTick)
        releaseWakeLock()
        ble?.updateMeasurement(0, false)
        updateState {
            it.copy(
                bpm = null,
                contact = false,
                lastSampleAtEpochMs = null,
                sensorSource = null,
                phase = if (it.serviceRunning && it.advertising) {
                    BroadcastSnapshot.PHASE_ADVERTISING
                } else {
                    it.phase
                },
            )
        }
    }

    private fun onHeartRateSample(bpm: Int, contact: Boolean, source: String) {
        if (!running) return
        if (bpm <= 0) {
            lastBpm = null
            lastContact = false
            lastBleSentAt = SystemClock.elapsedRealtime()
            ble?.updateMeasurement(0, false)
            updateState {
                it.copy(
                    phase = BroadcastSnapshot.PHASE_LIVE,
                    bpm = null,
                    contact = false,
                    lastSampleAtEpochMs = System.currentTimeMillis(),
                    sensorSource = source,
                )
            }
            return
        }
        lastBpm = bpm
        lastContact = contact
        lastBleSentAt = SystemClock.elapsedRealtime()
        ble?.updateMeasurement(bpm, contact)
        updateState {
            it.copy(
                phase = BroadcastSnapshot.PHASE_LIVE,
                bpm = bpm,
                contact = contact,
                lastSampleAtEpochMs = System.currentTimeMillis(),
                sensorSource = source,
                errorCode = null,
                errorDetail = null,
            )
        }
        updateNotification()
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "BeatCast::HeartRate",
        ).apply {
            setReferenceCounted(false)
            // Released explicitly when the last subscriber leaves or the
            // service stops. Android releases it if the process dies.
            acquire()
        }
    }

    private fun releaseWakeLock() {
        runCatching {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        }
        wakeLock = null
    }

    private fun enforcePowerLimits() {
        val now = System.currentTimeMillis()
        val maxSession = settings.maxSessionMinutes
        if (maxSession > 0 && now - startedAt >= maxSession * 60_000L) {
            stopBroadcast()
            return
        }

        val autoStop = settings.autoStopMinutes
        val idle = idleSince
        if (autoStop > 0 && idle != null && now - idle >= autoStop * 60_000L) {
            stopBroadcast()
        }
    }

    private fun refreshBattery() {
        val manager = getSystemService(BatteryManager::class.java) ?: return
        val percent = manager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            .takeIf { it in 0..100 }
        if (percent != null && percent != lastBatteryPercent) {
            lastBatteryPercent = percent
            updateState { it.copy(batteryPercent = percent) }
        }
    }

    private fun updateNotification(force: Boolean = false) {
        if (!running && !shuttingDown) return
        val now = SystemClock.elapsedRealtime()
        if (!force && now - lastNotificationAt < NOTIFICATION_MIN_INTERVAL_MS) return
        lastNotificationAt = now
        runCatching {
            getSystemService(android.app.NotificationManager::class.java)
                ?.notify(
                    NotificationFactory.NOTIFICATION_ID,
                    notifications.build(BroadcastStateStore.snapshot),
                )
        }
    }

    private fun updateState(transform: (BroadcastSnapshot) -> BroadcastSnapshot) {
        BroadcastStateStore.update(transform)
    }

    private fun registerBluetoothReceiver() {
        if (receiverRegistered) return
        val filter = IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED)
        if (Build.VERSION.SDK_INT >= 33) {
            registerReceiver(bluetoothReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(bluetoothReceiver, filter)
        }
        receiverRegistered = true
    }

    private fun unregisterBluetoothReceiver() {
        if (!receiverRegistered) return
        runCatching { unregisterReceiver(bluetoothReceiver) }
        receiverRegistered = false
    }

    // ---- BleBroadcaster.Listener ----

    override fun onAdvertisingStarted(mode: String) {
        if (!running) return
        idleSince = System.currentTimeMillis()
        updateState {
            it.copy(
                phase = if (it.clients > 0) {
                    BroadcastSnapshot.PHASE_LIVE
                } else {
                    BroadcastSnapshot.PHASE_ADVERTISING
                },
                advertising = true,
                errorCode = null,
                errorDetail = null,
            )
        }
        updateNotification(force = true)
    }

    override fun onAdvertisingFailed(errorCode: Int) {
        if (!running) return
        failAndStop("advertising_failed_$errorCode", "BLE advertising failed (code $errorCode)")
    }

    override fun onClientCountChanged(count: Int) {
        if (!running) return
        updateState {
            it.copy(
                clients = count,
                phase = when {
                    count > 0 -> BroadcastSnapshot.PHASE_LIVE
                    it.advertising -> BroadcastSnapshot.PHASE_ADVERTISING
                    else -> it.phase
                },
                advertising = it.advertising,
            )
        }
        if (count > 0) {
            idleSince = null
            startSensor()
        } else {
            idleSince = System.currentTimeMillis()
            stopSensor()
        }
        updateNotification(force = true)
    }

    override fun onSubscriberCountChanged(count: Int) {
        subscriberCount = count
        if (count > 0 && sensor?.isRunning == true) {
            mainHandler.removeCallbacks(bleTick)
            mainHandler.postDelayed(bleTick, BLE_HEARTBEAT_MS)
        } else if (count == 0) {
            mainHandler.removeCallbacks(bleTick)
        }
    }

    override fun onError(code: String, detail: String?) {
        if (!running) return
        failAndStop(code, detail)
    }

    override fun onDeviceName(name: String) {
        updateState { it.copy(deviceName = name) }
    }

    companion object {
        const val ACTION_START = "com.zihuagaochn.beatcast.action.START"
        const val ACTION_STOP = "com.zihuagaochn.beatcast.action.STOP"
        const val ACTION_UPDATE = "com.zihuagaochn.beatcast.action.UPDATE"

        private const val TICK_INTERVAL_MS = 30_000L
        private const val NOTIFICATION_MIN_INTERVAL_MS = 60_000L
        private const val BLE_HEARTBEAT_MS = 1_000L
        private const val ERROR_HOLD_MS = 400L
    }
}
