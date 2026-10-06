package com.example.autopulse_ai

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

/** Paired-device SPP transport only. ELM commands and vehicle parsing stay in Dart. */
class ElmBluetoothBridge(private val activity: Activity, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val methods = MethodChannel(messenger, "autopulse/obd/methods")
    private val events = EventChannel(messenger, "autopulse/obd/events")
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val generation = AtomicInteger(0)
    @Volatile private var socket: BluetoothSocket? = null
    private var sink: EventChannel.EventSink? = null
    private var permissionResult: MethodChannel.Result? = null
    private var disposed = false
    private val adapter: BluetoothAdapter?
        get() = activity.getSystemService(BluetoothManager::class.java)?.adapter

    init {
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
    }

    private fun permitted(): Boolean = Build.VERSION.SDK_INT < 31 ||
        activity.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "permission" -> {
                    if (permitted()) result.success(true)
                    else if (permissionResult != null) result.error("BUSY", "Permission request already active.", null)
                    else {
                        permissionResult = result
                        activity.requestPermissions(arrayOf(Manifest.permission.BLUETOOTH_CONNECT), PERMISSION_REQUEST)
                    }
                }
                "settings" -> {
                    activity.startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
                    result.success(null)
                }
                "devices" -> {
                    val bt = requireAdapter()
                    val devices = bt.bondedDevices.filter { it.type != BluetoothDevice.DEVICE_TYPE_LE }
                        .map { mapOf("name" to (it.name ?: "Bluetooth adapter"), "address" to it.address) }
                        .sortedBy { it["name"] }
                    result.success(devices)
                }
                "connect" -> connect(call.argument<String>("address"), result)
                "write" -> {
                    val bytes = call.argument<ByteArray>("bytes") ?: throw IllegalArgumentException("Missing bytes.")
                    val active = socket ?: throw IOException("Adapter is disconnected.")
                    worker.execute {
                        try {
                            active.outputStream.write(bytes)
                            active.outputStream.flush()
                            main.post { result.success(null) }
                        } catch (error: Exception) {
                            main.post { result.error("WRITE_FAILED", "Could not write to adapter.", null) }
                        }
                    }
                }
                "disconnect" -> {
                    closeConnection()
                    emit(mapOf("type" to "disconnected"), generation.get())
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (error: SecurityException) {
            result.error("PERMISSION_DENIED", "Bluetooth permission is required.", null)
        } catch (error: Exception) {
            result.error("BLUETOOTH_ERROR", error.message ?: "Bluetooth unavailable.", null)
        }
    }

    private fun requireAdapter(): BluetoothAdapter {
        if (!permitted()) throw SecurityException()
        val bt = adapter ?: throw IOException("Bluetooth is unavailable on this phone.")
        if (!bt.isEnabled) throw IOException("Bluetooth is turned off.")
        return bt
    }

    private fun connect(address: String?, result: MethodChannel.Result) {
        val bt = requireAdapter()
        if (address == null || !BluetoothAdapter.checkBluetoothAddress(address)) {
            throw IllegalArgumentException("Invalid adapter address.")
        }
        val device = bt.getRemoteDevice(address)
        if (device.bondState != BluetoothDevice.BOND_BONDED) throw IOException("Pair this adapter in Bluetooth settings first.")
        closeConnection()
        val token = generation.get()
        val candidate = device.createRfcommSocketToServiceRecord(SPP_UUID)
        socket = candidate
        // Closing the socket from the main thread also cancels a blocking connect/read.
        main.postDelayed({ if (token == generation.get() && !candidate.isConnected) closeConnection() }, 15000)
        worker.execute {
            try {
                candidate.connect()
                if (token != generation.get()) throw IOException("Connection cancelled.")
                main.post { result.success(null) }
                emit(mapOf("type" to "connected"), token)
                Thread({ readLoop(candidate, token) }, "autopulse-obd-reader").start()
            } catch (error: Exception) {
                try { candidate.close() } catch (_: IOException) { }
                if (token == generation.get()) closeConnection()
                main.post { result.error("CONNECT_FAILED", "Could not connect. Check pairing, adapter power, and other scanner apps.", null) }
            }
        }
    }

    private fun readLoop(active: BluetoothSocket, token: Int) {
        try {
            val buffer = ByteArray(4096)
            while (token == generation.get()) {
                val count = active.inputStream.read(buffer)
                if (count < 0) break
                emit(mapOf("type" to "data", "bytes" to buffer.copyOf(count)), token)
            }
        } catch (_: IOException) {
            // An intentional close follows this path too; stale readers must not affect a new connection.
        } finally {
            if (token == generation.get()) {
                closeConnection()
                emit(mapOf("type" to "disconnected"), generation.get())
            }
        }
    }

    private fun emit(event: Map<String, Any>, token: Int) {
        main.post { if (!disposed && token == generation.get()) sink?.success(event) }
    }

    private fun closeConnection() {
        generation.incrementAndGet()
        val old = socket
        socket = null
        try { old?.close() } catch (_: IOException) { }
    }

    fun onPermissionResult(requestCode: Int, grants: IntArray) {
        if (requestCode != PERMISSION_REQUEST) return
        permissionResult?.success(grants.isNotEmpty() && grants.all { it == PackageManager.PERMISSION_GRANTED })
        permissionResult = null
    }

    override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) { sink = eventSink }
    override fun onCancel(arguments: Any?) { sink = null; closeConnection() }

    fun dispose() {
        disposed = true
        closeConnection()
        permissionResult?.success(false)
        permissionResult = null
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        worker.shutdownNow()
        sink = null
    }

    companion object {
        private const val PERMISSION_REQUEST = 7041
        private val SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    }
}
