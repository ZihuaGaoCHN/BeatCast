package com.zihuagaochn.beatcast.core

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build

/**
 * Wear OS moved health permissions in API 36:
 *   <= 35 : BODY_SENSORS / BODY_SENSORS_BACKGROUND
 *   >= 36 : READ_HEART_RATE / READ_HEALTH_DATA_IN_BACKGROUND
 *
 * The manifest declares all four. Only the pair appropriate for the current
 * platform is ever requested at runtime.
 */
object Permissions {
    private const val READ_HEART_RATE = "android.permission.health.READ_HEART_RATE"
    private const val READ_HEALTH_DATA_IN_BACKGROUND =
        "android.permission.health.READ_HEALTH_DATA_IN_BACKGROUND"

    data class PermissionSnapshot(
        val sensorGranted: Boolean,
        val backgroundSensorGranted: Boolean,
        val bluetoothGranted: Boolean,
        val notificationsGranted: Boolean,
        val backgroundSupported: Boolean,
    ) {
        val readyToBroadcast: Boolean
            get() = sensorGranted && backgroundSensorGranted && bluetoothGranted

        fun toMap(): Map<String, Any> = mapOf(
            "sensorGranted" to sensorGranted,
            "backgroundSensorGranted" to backgroundSensorGranted,
            "bluetoothGranted" to bluetoothGranted,
            "notificationsGranted" to notificationsGranted,
            "backgroundSupported" to backgroundSupported,
            "ready" to readyToBroadcast,
        )
    }

    fun sensorPermission(): String =
        if (Build.VERSION.SDK_INT >= 36) {
            READ_HEART_RATE
        } else {
            Manifest.permission.BODY_SENSORS
        }

    fun backgroundSensorPermission(): String? = when {
        Build.VERSION.SDK_INT >= 36 -> READ_HEALTH_DATA_IN_BACKGROUND
        Build.VERSION.SDK_INT >= 31 -> Manifest.permission.BODY_SENSORS_BACKGROUND
        else -> null
    }

    fun bluetoothPermissions(): Array<String> =
        if (Build.VERSION.SDK_INT >= 31) {
            arrayOf(
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.BLUETOOTH_ADVERTISE,
            )
        } else {
            emptyArray()
        }

    fun notificationPermission(): String? =
        if (Build.VERSION.SDK_INT >= 33) Manifest.permission.POST_NOTIFICATIONS else null

    fun coreMissing(context: Context): List<String> {
        val missing = mutableListOf<String>()
        if (!granted(context, sensorPermission())) missing += sensorPermission()
        bluetoothPermissions().forEach { permission ->
            if (!granted(context, permission)) missing += permission
        }
        notificationPermission()?.let { permission ->
            if (!granted(context, permission)) missing += permission
        }
        return missing
    }

    fun backgroundMissing(context: Context): String? {
        val permission = backgroundSensorPermission() ?: return null
        return permission.takeIf { !granted(context, it) }
    }

    fun status(context: Context): PermissionSnapshot {
        val backgroundSupported = backgroundSensorPermission() != null
        return PermissionSnapshot(
            sensorGranted = granted(context, sensorPermission()),
            backgroundSensorGranted = backgroundMissing(context) == null,
            bluetoothGranted = bluetoothPermissions().all { granted(context, it) },
            notificationsGranted = notificationPermission()?.let { granted(context, it) } ?: true,
            backgroundSupported = backgroundSupported,
        )
    }

    fun granted(context: Context, permission: String): Boolean =
        context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    /**
     * Permissions that are strictly required to start. Notifications are
     * requested too, but Android allows a foreground service without them;
     * blocking the core feature on a status icon would be hostile.
     */
    fun missingForStart(context: Context): List<String> {
        val missing = mutableListOf<String>()
        if (!granted(context, sensorPermission())) missing += sensorPermission()
        bluetoothPermissions().forEach { permission ->
            if (!granted(context, permission)) missing += permission
        }
        backgroundMissing(context)?.let { missing += it }
        return missing
    }
}
