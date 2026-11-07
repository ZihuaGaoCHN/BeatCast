package com.zihuagaochn.beatcast

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import com.zihuagaochn.beatcast.core.BroadcastStateStore
import com.zihuagaochn.beatcast.core.Permissions
import com.zihuagaochn.beatcast.core.SettingsStore
import com.zihuagaochn.beatcast.model.BroadcastSettings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var settingsStore: SettingsStore

    private var eventSink: EventChannel.EventSink? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var resumed = false

    private val stateListener: (com.zihuagaochn.beatcast.model.BroadcastSnapshot) -> Unit = {
        // While the screen is off Flutter has no useful work to do. Keeping
        // the 1 Hz event bridge quiet is part of the battery budget.
        if (resumed) eventSink?.success(buildBootstrap())
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        settingsStore = SettingsStore(this)
        // The service may not be alive yet. Seed a useful name for the idle UI.
        val name = runCatching {
            (getSystemService(BluetoothManager::class.java))?.adapter?.name
        }.getOrNull()
        if (!name.isNullOrBlank() && BroadcastStateStore.snapshot.deviceName == "Wear OS watch") {
            BroadcastStateStore.update { it.copy(deviceName = name) }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL,
        )
        methodChannel.setMethodCallHandler(::handleMethodCall)

        eventChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EVENT_CHANNEL,
        )
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                BroadcastStateStore.addListener(stateListener)
                events?.success(buildBootstrap())
            }

            override fun onCancel(arguments: Any?) {
                BroadcastStateStore.removeListener(stateListener)
                eventSink = null
            }
        })
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "bootstrap" -> result.success(buildBootstrap())

            "startBroadcast" -> startBroadcast(result)

            "stopBroadcast" -> {
                stopService(Intent(this, BeatCastService::class.java))
                result.success(mapOf("ok" to true))
            }

            "updateSettings" -> {
                val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                val updated = BroadcastSettings.sanitize(
                    mode = args["advertisingMode"] as? String,
                    autoStop = (args["autoStopMinutes"] as? Number)?.toInt(),
                    maxSession = (args["maxSessionMinutes"] as? Number)?.toInt(),
                )
                settingsStore.save(updated)
                if (BroadcastStateStore.snapshot.serviceRunning) {
                    runCatching {
                        startService(
                            Intent(this, BeatCastService::class.java)
                                .setAction(BeatCastService.ACTION_UPDATE),
                        )
                    }
                }
                result.success(updated.toMap())
            }

            "requestCorePermissions" -> requestCorePermissions(result)

            "requestBackgroundPermission" -> requestBackgroundPermission(result)

            "markPermissionsPrompted" -> {
                settingsStore.markPromptedPermissions()
                result.success(true)
            }

            "openAppSettings" -> {
                result.success(
                    runCatching {
                        startActivity(
                            Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:$packageName"),
                            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                        true
                    }.getOrDefault(false),
                )
            }

            "openBluetoothSettings" -> {
                result.success(
                    runCatching {
                        startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
                        true
                    }.getOrDefault(false),
                )
            }

            "requestEnableBluetooth" -> {
                if (Build.VERSION.SDK_INT >= 31 &&
                    !Permissions.granted(this, android.Manifest.permission.BLUETOOTH_CONNECT)
                ) {
                    result.success(false)
                } else {
                    result.success(
                        runCatching {
                            startActivity(Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE))
                            true
                        }.getOrDefault(false),
                    )
                }
            }

            else -> result.notImplemented()
        }
    }

    private fun startBroadcast(result: MethodChannel.Result) {
        val permissions = Permissions.status(this)
        if (!permissions.readyToBroadcast) {
            result.success(
                mapOf(
                    "ok" to false,
                    "error" to "permissions_missing",
                    "permissions" to permissions.toMap(),
                ),
            )
            return
        }

        val adapter = getSystemService(BluetoothManager::class.java)?.adapter
        if (adapter == null) {
            result.success(mapOf("ok" to false, "error" to "bluetooth_unavailable"))
            return
        }
        if (!adapter.isEnabled) {
            result.success(mapOf("ok" to false, "error" to "bluetooth_off"))
            return
        }
        val advertiserAvailable = runCatching { adapter.bluetoothLeAdvertiser != null }
            .getOrDefault(false)
        if (!advertiserAvailable) {
            result.success(mapOf("ok" to false, "error" to "advertising_unsupported"))
            return
        }

        try {
            startForegroundService(
                Intent(this, BeatCastService::class.java)
                    .setAction(BeatCastService.ACTION_START),
            )
            result.success(mapOf("ok" to true))
        } catch (security: SecurityException) {
            result.success(
                mapOf(
                    "ok" to false,
                    "error" to "permission_denied",
                    "detail" to security.message,
                ),
            )
        } catch (error: RuntimeException) {
            result.success(
                mapOf(
                    "ok" to false,
                    "error" to "service_start_failed",
                    "detail" to error.message,
                ),
            )
        }
    }

    private fun requestCorePermissions(result: MethodChannel.Result) {
        val missing = Permissions.coreMissing(this)
        if (missing.isEmpty()) {
            result.success(buildBootstrap())
            return
        }
        requestPermissionsWithResult(missing.toTypedArray(), REQUEST_CORE, result)
    }

    private fun requestBackgroundPermission(result: MethodChannel.Result) {
        val missing = Permissions.backgroundMissing(this)
        if (missing == null) {
            result.success(buildBootstrap())
            return
        }
        requestPermissionsWithResult(arrayOf(missing), REQUEST_BACKGROUND, result)
    }

    private fun requestPermissionsWithResult(
        permissions: Array<String>,
        code: Int,
        result: MethodChannel.Result,
    ) {
        if (pendingPermissionResult != null) {
            result.error("permission_request_busy", "Another permission request is in flight", null)
            return
        }
        pendingPermissionResult = result
        requestPermissions(permissions, code)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (requestCode == REQUEST_CORE || requestCode == REQUEST_BACKGROUND) {
            val result = pendingPermissionResult
            pendingPermissionResult = null
            result?.success(buildBootstrap())
            emitBootstrap()
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onResume() {
        super.onResume()
        resumed = true
        emitBootstrap()
    }

    override fun onPause() {
        resumed = false
        super.onPause()
    }

    override fun onDestroy() {
        BroadcastStateStore.removeListener(stateListener)
        eventSink = null
        if (::methodChannel.isInitialized) {
            methodChannel.setMethodCallHandler(null)
        }
        if (::eventChannel.isInitialized) {
            eventChannel.setStreamHandler(null)
        }
        super.onDestroy()
    }

    private fun emitBootstrap() {
        if (resumed) eventSink?.success(buildBootstrap())
    }

    private fun buildBootstrap(): Map<String, Any?> {
        val adapter = runCatching {
            getSystemService(BluetoothManager::class.java)?.adapter
        }.getOrNull()
        val permissions = Permissions.status(this)
        val bluetoothEnabled = runCatching { adapter?.isEnabled == true }.getOrDefault(false)
        val advertisingSupported = if (!permissions.bluetoothGranted) {
            true // Unknown until Bluetooth permissions are granted.
        } else {
            runCatching { adapter?.bluetoothLeAdvertiser != null }.getOrDefault(false)
        }
        return mapOf(
            "broadcast" to BroadcastStateStore.snapshot.toMap(),
            "permissions" to permissions.toMap(),
            "settings" to settingsStore.load().toMap(),
            "bluetoothEnabled" to bluetoothEnabled,
            "advertisingSupported" to advertisingSupported,
            "firstPermissionRun" to !settingsStore.hasPromptedPermissions(),
            "appVersion" to versionName(),
        )
    }

    private fun versionName(): String = runCatching {
        if (Build.VERSION.SDK_INT >= 33) {
            packageManager.getPackageInfo(
                packageName,
                PackageManager.PackageInfoFlags.of(0),
            ).versionName
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageInfo(packageName, 0).versionName
        }
    }.getOrNull() ?: "1.0.0"

    companion object {
        private const val METHOD_CHANNEL = "dev.beatcast/app"
        private const val EVENT_CHANNEL = "dev.beatcast/events"
        private const val REQUEST_CORE = 0xBC01
        private const val REQUEST_BACKGROUND = 0xBC02
    }
}
