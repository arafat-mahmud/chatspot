package com.example.chatspot

import android.content.Context
import android.os.PowerManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var proximityWakeLock: PowerManager.WakeLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "chatspot/call")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setProximitySensor" -> {
                        setProximitySensor(call.arguments as? Boolean ?: false)
                        result.success(null)
                    }
                    "setKeepScreenOn" -> {
                        if (call.arguments as? Boolean == true) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // Turns the screen off while the phone is held to the ear during a call.
    private fun setProximitySensor(enabled: Boolean) {
        if (enabled) {
            if (proximityWakeLock == null) {
                val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                if (!powerManager.isWakeLockLevelSupported(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK)) return
                proximityWakeLock = powerManager.newWakeLock(
                    PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK,
                    "chatspot:call-proximity"
                )
            }
            proximityWakeLock?.let { if (!it.isHeld) it.acquire() }
        } else {
            proximityWakeLock?.let {
                if (it.isHeld) it.release(PowerManager.RELEASE_FLAG_WAIT_FOR_NO_PROXIMITY)
            }
        }
    }

    override fun onDestroy() {
        setProximitySensor(false)
        super.onDestroy()
    }
}
