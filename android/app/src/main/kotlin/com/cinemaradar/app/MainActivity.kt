package com.cinemaradar.app

import android.app.ActivityManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val backgroundAccessChannel = "com.cinemaradar.app/background_access"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            backgroundAccessChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getStatus" -> result.success(backgroundAccessStatus())
                "openBackgroundSettings" -> result.success(
                    openSettings(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
                )
                "openAppSettings" -> result.success(openAppDetails())
                else -> result.notImplemented()
            }
        }
    }

    private fun backgroundAccessStatus(): Map<String, Any> {
        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        val activityManager = getSystemService(ACTIVITY_SERVICE) as ActivityManager
        return mapOf(
            "notificationsEnabled" to
                NotificationManagerCompat.from(this).areNotificationsEnabled(),
            "batteryOptimizationExempt" to
                powerManager.isIgnoringBatteryOptimizations(packageName),
            "backgroundRestricted" to
                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
                    activityManager.isBackgroundRestricted),
            "settingsAvailable" to true,
            "scheduledBackgroundSupported" to true,
        )
    }

    private fun openSettings(action: String): Boolean {
        return try {
            startActivity(Intent(action))
            true
        } catch (_: Exception) {
            openAppDetails()
        }
    }

    private fun openAppDetails(): Boolean {
        return try {
            startActivity(
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:$packageName"),
                ),
            )
            true
        } catch (_: Exception) {
            false
        }
    }
}
