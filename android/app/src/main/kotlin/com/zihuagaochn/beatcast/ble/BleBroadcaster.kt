package com.zihuagaochn.beatcast.ble

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import com.zihuagaochn.beatcast.model.BroadcastSettings
import com.zihuagaochn.beatcast.model.HeartRateMeasurement
import java.util.ArrayDeque
import java.util.Collections
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * Owns the standard Bluetooth SIG Heart Rate Profile:
 *
 *   Heart Rate Service (0x180D)
 *     Heart Rate Measurement (0x2A37)  READ | NOTIFY + CCCD
 *     Body Sensor Location  (0x2A38)  READ  (wrist)
 *   Device Information Service (0x180A)
 *
 * It also advertises the 0x180D service so gym equipment, bike computers and
 * phone apps discover the watch as a normal heart-rate strap.
 */
@SuppressLint("MissingPermission")
class BleBroadcaster(
    private val context: Context,
    private val listener: Listener,
) {
    interface Listener {
        fun onAdvertisingStarted(mode: String)
        fun onAdvertisingFailed(errorCode: Int)
        fun onClientCountChanged(count: Int)
        fun onSubscriberCountChanged(count: Int)
        fun onError(code: String, detail: String?)
        fun onDeviceName(name: String)
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val bluetoothManager = context.getSystemService(BluetoothManager::class.java)

    private var gattServer: BluetoothGattServer? = null
    private var advertiser: BluetoothLeAdvertiser? = null
    private var advertiseCallback: AdvertiseCallback? = null
    private var heartRateCharacteristic: BluetoothGattCharacteristic? = null

    private val subscribed = Collections.newSetFromMap(ConcurrentHashMap<BluetoothDevice, Boolean>())
    private val connected = Collections.newSetFromMap(ConcurrentHashMap<BluetoothDevice, Boolean>())
    private val serviceQueue = ArrayDeque<BluetoothGattService>()
    private var addingService = false
    private var serviceTimeoutPosted = false

    private var advertising = false
    private var advertisingStarting = false
    private var started = false
    private var settings = BroadcastSettings.DEFAULTS
    private var includeNameInAdvertising = true
    private var currentMeasurement = HeartRateMeasurement.empty()

    val subscriberCount: Int
        get() = subscribed.size

    fun advertisedName(): String {
        val adapter = bluetoothManager?.adapter
        return runCatching { adapter?.name }.getOrNull()
            ?.takeIf { it.isNotBlank() }
            ?: "Wear OS watch"
    }

    fun isBluetoothEnabled(): Boolean = runCatching {
        bluetoothManager?.adapter?.isEnabled == true
    }.getOrDefault(false)

    fun supportsAdvertising(): Boolean = runCatching {
        val adapter = bluetoothManager?.adapter ?: return false
        adapter.bluetoothLeAdvertiser != null
    }.getOrDefault(false)

    fun start(newSettings: BroadcastSettings) {
        stop()
        settings = newSettings
        started = true
        includeNameInAdvertising = true

        val adapter = bluetoothManager?.adapter
        if (adapter == null) {
            listener.onError("bluetooth_unavailable", "This watch has no Bluetooth adapter")
            return
        }
        if (!adapter.isEnabled) {
            listener.onError("bluetooth_off", "Bluetooth is turned off")
            return
        }

        val name = advertisedName()
        listener.onDeviceName(name)

        advertiser = runCatching { adapter.bluetoothLeAdvertiser }.getOrNull()
        if (advertiser == null) {
            listener.onError(
                "advertising_unsupported",
                "This watch does not expose BLE peripheral advertising",
            )
            return
        }

        val server = runCatching {
            bluetoothManager?.openGattServer(context, gattCallback)
        }.getOrNull()
        if (server == null) {
            listener.onError("gatt_server_failed", "Could not open a GATT server")
            return
        }
        gattServer = server

        serviceQueue.clear()
        serviceQueue.add(buildHeartRateService())
        serviceQueue.add(buildDeviceInformationService())
        addNextService()
    }

    fun stop() {
        started = false
        stopAdvertising()
        subscribed.clear()
        connected.clear()
        addingService = false
        serviceQueue.clear()
        heartRateCharacteristic = null
        runCatching {
            gattServer?.clearServices()
            gattServer?.close()
        }
        gattServer = null
        advertiser = null
        mainHandler.post {
            listener.onClientCountChanged(0)
            listener.onSubscriberCountChanged(0)
        }
    }

    fun updateMeasurement(bpm: Int, contactDetected: Boolean) {
        val payload = HeartRateMeasurement.encode(bpm, contactDetected)
        currentMeasurement = payload
        val characteristic = heartRateCharacteristic ?: return
        characteristic.value = payload

        val targets = subscribed.toList()
        if (targets.isEmpty()) return
        targets.forEach { device ->
            val sent = runCatching {
                if (Build.VERSION.SDK_INT >= 33) {
                    gattServer?.notifyCharacteristicChanged(
                        device,
                        characteristic,
                        false,
                        payload,
                    ) == BluetoothGatt.GATT_SUCCESS
                } else {
                    @Suppress("DEPRECATION")
                    characteristic.value = payload
                    @Suppress("DEPRECATION")
                    gattServer?.notifyCharacteristicChanged(device, characteristic, false) == true
                }
            }.getOrDefault(false)
            if (!sent) {
                // A stale device will be cleaned up by its disconnect callback.
                // Do not log BPM or device identifiers in release builds.
            }
        }
    }

    fun restartAdvertising(mode: BroadcastSettings) {
        val oldMode = settings.advertisingMode
        settings = mode
        if (!started) return
        if (oldMode == mode.advertisingMode && advertising) return
        stopAdvertising()
        if (gattServer?.getService(HEART_RATE_SERVICE_UUID) == null) {
            // Services are not ready yet; startAdvertising will run when they are.
            return
        }
        mainHandler.postDelayed({ if (started) startAdvertising() }, 250L)
    }

    private fun addNextService() {
        if (!started) return
        if (addingService) return
        val next = serviceQueue.pollFirst()
        if (next == null) {
            startAdvertising()
            return
        }

        val server = gattServer ?: return
        addingService = true
        val accepted = runCatching { server.addService(next) }.getOrDefault(false)
        if (!accepted) {
            addingService = false
            if (next.uuid == HEART_RATE_SERVICE_UUID) {
                listener.onError("service_add_failed", "Could not add the Heart Rate Service")
                return
            }
            addNextService()
            return
        }

        // Some OEM Bluetooth stacks never deliver onServiceAdded. Move on once
        // the service is visibly present so advertising never hangs forever.
        if (!serviceTimeoutPosted) {
            serviceTimeoutPosted = true
            mainHandler.postDelayed({
                serviceTimeoutPosted = false
                if (started && !advertising) {
                    addingService = false
                    if (gattServer?.getService(HEART_RATE_SERVICE_UUID) != null) {
                        startAdvertising()
                    } else {
                        listener.onError(
                            "service_add_failed",
                            "The Heart Rate Service did not register",
                        )
                    }
                }
            }, SERVICE_TIMEOUT_MS)
        }
    }

    private fun startAdvertising() {
        if (!started || advertising || advertisingStarting) return
        val adv = advertiser ?: return
        val settingsBuilder = AdvertiseSettings.Builder()
            .setAdvertiseMode(
                if (settings.advertisingMode == BroadcastSettings.MODE_LOW_POWER) {
                    AdvertiseSettings.ADVERTISE_MODE_LOW_POWER
                } else {
                    AdvertiseSettings.ADVERTISE_MODE_BALANCED
                },
            )
            .setTxPowerLevel(
                if (settings.advertisingMode == BroadcastSettings.MODE_LOW_POWER) {
                    AdvertiseSettings.ADVERTISE_TX_POWER_LOW
                } else {
                    AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM
                },
            )
            .setConnectable(true)
            .setTimeout(0)
            .build()

        // The 16-bit service UUID is the reliable signal for HR clients. The
        // watch name goes into the scan response so the 31-byte advertising
        // packet can never overflow.
        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .setIncludeTxPowerLevel(false)
            .addServiceUuid(ParcelUuid(HEART_RATE_SERVICE_UUID))
            .build()
        val scanResponse = AdvertiseData.Builder()
            .setIncludeDeviceName(includeNameInAdvertising)
            .setIncludeTxPowerLevel(false)
            .build()

        val callback = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
                mainHandler.post {
                    if (advertiseCallback !== this) return@post
                    advertising = true
                    advertisingStarting = false
                    listener.onAdvertisingStarted(settings.advertisingMode)
                }
            }

            override fun onStartFailure(errorCode: Int) {
                mainHandler.post {
                    if (advertiseCallback !== this) return@post
                    advertising = false
                    advertisingStarting = false
                    if (errorCode == ADVERTISE_FAILED_DATA_TOO_LARGE && includeNameInAdvertising) {
                        includeNameInAdvertising = false
                        startAdvertising()
                    } else {
                        listener.onAdvertisingFailed(errorCode)
                    }
                }
            }
        }
        advertiseCallback = callback
        advertisingStarting = true
        runCatching {
            adv.startAdvertising(settingsBuilder, data, scanResponse, callback)
        }.onFailure { error ->
            advertising = false
            advertisingStarting = false
            listener.onError("advertising_start_failed", error.message)
        }
    }

    private fun stopAdvertising() {
        advertising = false
        advertisingStarting = false
        val callback = advertiseCallback
        advertiseCallback = null
        if (callback != null) {
            runCatching { advertiser?.stopAdvertising(callback) }
        }
    }

    private fun buildHeartRateService(): BluetoothGattService {
        val measurement = BluetoothGattCharacteristic(
            HEART_RATE_MEASUREMENT_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ or
                BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ,
        ).apply {
            value = currentMeasurement
            addDescriptor(
                BluetoothGattDescriptor(
                    CLIENT_CHARACTERISTIC_CONFIG_UUID,
                    BluetoothGattDescriptor.PERMISSION_READ or
                        BluetoothGattDescriptor.PERMISSION_WRITE,
                ),
            )
        }
        heartRateCharacteristic = measurement

        val bodySensorLocation = BluetoothGattCharacteristic(
            BODY_SENSOR_LOCATION_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ,
            BluetoothGattCharacteristic.PERMISSION_READ,
        ).apply {
            value = byteArrayOf(BODY_SENSOR_WRIST)
        }

        return BluetoothGattService(
            HEART_RATE_SERVICE_UUID,
            BluetoothGattService.SERVICE_TYPE_PRIMARY,
        ).apply {
            addCharacteristic(measurement)
            addCharacteristic(bodySensorLocation)
        }
    }

    private fun buildDeviceInformationService(): BluetoothGattService {
        fun readOnly(uuid: UUID, value: String) = BluetoothGattCharacteristic(
            uuid,
            BluetoothGattCharacteristic.PROPERTY_READ,
            BluetoothGattCharacteristic.PERMISSION_READ,
        ).apply { this.value = value.toByteArray(Charsets.UTF_8) }

        return BluetoothGattService(
            DEVICE_INFORMATION_SERVICE_UUID,
            BluetoothGattService.SERVICE_TYPE_PRIMARY,
        ).apply {
            addCharacteristic(readOnly(MANUFACTURER_NAME_UUID, "BeatCast"))
            addCharacteristic(readOnly(MODEL_NUMBER_UUID, "Wear OS watch"))
            addCharacteristic(readOnly(FIRMWARE_REVISION_UUID, "1.0"))
        }
    }

    private val gattCallback = object : BluetoothGattServerCallback() {
        override fun onServiceAdded(status: Int, service: BluetoothGattService) {
            mainHandler.post {
                if (!started) return@post
                addingService = false
                if (status != BluetoothGatt.GATT_SUCCESS &&
                    service.uuid == HEART_RATE_SERVICE_UUID
                ) {
                    listener.onError(
                        "service_add_failed",
                        "Heart Rate Service status=$status",
                    )
                    return@post
                }
                addNextService()
            }
        }

        override fun onConnectionStateChange(
            device: BluetoothDevice,
            status: Int,
            newState: Int,
        ) {
            mainHandler.post {
                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    connected.add(device)
                    listener.onClientCountChanged(connected.size)
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                    val wasSubscribed = subscribed.remove(device)
                    connected.remove(device)
                    listener.onClientCountChanged(connected.size)
                    if (wasSubscribed) listener.onSubscriberCountChanged(subscribed.size)
                }
            }
        }

        override fun onDescriptorWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            descriptor: BluetoothGattDescriptor,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray,
        ) {
            mainHandler.post {
                val characteristic = descriptor.characteristic
                val isCccd = descriptor.uuid == CLIENT_CHARACTERISTIC_CONFIG_UUID &&
                    characteristic?.uuid == HEART_RATE_MEASUREMENT_UUID

                if (!isCccd || preparedWrite || offset != 0) {
                    if (responseNeeded) {
                        gattServer?.sendResponse(
                            device,
                            requestId,
                            BluetoothGatt.GATT_REQUEST_NOT_SUPPORTED,
                            0,
                            null,
                        )
                    }
                    return@post
                }

                val enabled = value.contentEquals(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
                // Acknowledge the CCCD write before sending the first
                // notification. Some centrals discard notifications that
                // arrive before the write response.
                if (responseNeeded) {
                    gattServer?.sendResponse(
                        device,
                        requestId,
                        BluetoothGatt.GATT_SUCCESS,
                        0,
                        null,
                    )
                }
                val wasSubscribed = subscribed.contains(device)
                if (enabled) {
                    subscribed.add(device)
                    val payload = currentMeasurement
                    val characteristicToNotify = heartRateCharacteristic
                    if (characteristicToNotify != null) {
                        runCatching {
                            if (Build.VERSION.SDK_INT >= 33) {
                                gattServer?.notifyCharacteristicChanged(
                                    device,
                                    characteristicToNotify,
                                    false,
                                    payload,
                                )
                            } else {
                                @Suppress("DEPRECATION")
                                characteristicToNotify.value = payload
                                @Suppress("DEPRECATION")
                                gattServer?.notifyCharacteristicChanged(
                                    device,
                                    characteristicToNotify,
                                    false,
                                )
                            }
                        }
                    }
                } else {
                    subscribed.remove(device)
                }
                if (wasSubscribed != enabled) {
                    listener.onSubscriberCountChanged(subscribed.size)
                }
            }
        }

        override fun onDescriptorReadRequest(
            device: BluetoothDevice,
            requestId: Int,
            offset: Int,
            descriptor: BluetoothGattDescriptor,
        ) {
            mainHandler.post {
                if (descriptor.uuid != CLIENT_CHARACTERISTIC_CONFIG_UUID) {
                    gattServer?.sendResponse(
                        device,
                        requestId,
                        BluetoothGatt.GATT_REQUEST_NOT_SUPPORTED,
                        0,
                        null,
                    )
                    return@post
                }
                val value = if (subscribed.contains(device)) {
                    BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                } else {
                    BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE
                }
                if (offset < 0 || offset > value.size) {
                    gattServer?.sendResponse(
                        device,
                        requestId,
                        BluetoothGatt.GATT_INVALID_OFFSET,
                        0,
                        null,
                    )
                } else {
                    gattServer?.sendResponse(
                        device,
                        requestId,
                        BluetoothGatt.GATT_SUCCESS,
                        offset,
                        value.copyOfRange(offset, value.size),
                    )
                }
            }
        }

        override fun onCharacteristicReadRequest(
            device: BluetoothDevice,
            requestId: Int,
            offset: Int,
            characteristic: BluetoothGattCharacteristic,
        ) {
            mainHandler.post {
                val value = characteristic.value ?: ByteArray(0)
                if (offset < 0 || offset > value.size) {
                    gattServer?.sendResponse(
                        device,
                        requestId,
                        BluetoothGatt.GATT_INVALID_OFFSET,
                        0,
                        null,
                    )
                    return@post
                }
                val slice = value.copyOfRange(offset, value.size)
                gattServer?.sendResponse(
                    device,
                    requestId,
                    BluetoothGatt.GATT_SUCCESS,
                    offset,
                    slice,
                )
            }
        }

        override fun onCharacteristicWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            characteristic: BluetoothGattCharacteristic,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray,
        ) {
            if (responseNeeded) {
                mainHandler.post {
                    gattServer?.sendResponse(
                        device,
                        requestId,
                        BluetoothGatt.GATT_WRITE_NOT_PERMITTED,
                        0,
                        null,
                    )
                }
            }
        }
    }

    companion object {
        val HEART_RATE_SERVICE_UUID: UUID =
            UUID.fromString("0000180D-0000-1000-8000-00805F9B34FB")
        val HEART_RATE_MEASUREMENT_UUID: UUID =
            UUID.fromString("00002A37-0000-1000-8000-00805F9B34FB")
        val BODY_SENSOR_LOCATION_UUID: UUID =
            UUID.fromString("00002A38-0000-1000-8000-00805F9B34FB")
        val CLIENT_CHARACTERISTIC_CONFIG_UUID: UUID =
            UUID.fromString("00002902-0000-1000-8000-00805F9B34FB")
        val DEVICE_INFORMATION_SERVICE_UUID: UUID =
            UUID.fromString("0000180A-0000-1000-8000-00805F9B34FB")
        val MANUFACTURER_NAME_UUID: UUID =
            UUID.fromString("00002A29-0000-1000-8000-00805F9B34FB")
        val MODEL_NUMBER_UUID: UUID =
            UUID.fromString("00002A24-0000-1000-8000-00805F9B34FB")
        val FIRMWARE_REVISION_UUID: UUID =
            UUID.fromString("00002A26-0000-1000-8000-00805F9B34FB")

        private const val BODY_SENSOR_WRIST: Byte = 0x02
        private const val SERVICE_TIMEOUT_MS = 2_500L
        private const val ADVERTISE_FAILED_DATA_TOO_LARGE = 1
    }
}
