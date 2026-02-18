package com.example.myapp

import android.content.Context
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val WAKELOCK_CHANNEL = "wakelock_service"
    private val FOREGROUND_CHANNEL = "foreground_service"
    private val RECORDING_CHANNEL = "recording_storage"
    private var wakeLock: PowerManager.WakeLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WAKELOCK_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enable" -> {
                    enableWakeLock()
                    result.success(null)
                }
                "disable" -> {
                    disableWakeLock()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            FOREGROUND_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val args = call.arguments as? Map<*, *>
                    val isPremium = args?.get("isPremium") as? Boolean ?: false
                    RecordingForegroundService.startService(applicationContext, isPremium)
                    result.success(null)
                }
                "stop" -> {
                    RecordingForegroundService.stopService(applicationContext)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            RECORDING_CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method == "list") {
                val recordings = RecordingStorage(applicationContext).listAsMaps()
                result.success(recordings)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun enableWakeLock() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "AIStudyMate::RecordingWakeLock"
        )
        wakeLock?.acquire()
    }

    private fun disableWakeLock() {
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
            }
        }
        wakeLock = null
    }

    override fun onDestroy() {
        disableWakeLock()
        super.onDestroy()
    }
}
