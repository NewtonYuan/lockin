package com.example.lockin

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.os.Process
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterActivity() {
    private val trackedDailyTimeLimitKeys = listOf(
        "instagram_app",
        "youtube_app",
        "tiktok_app",
        "snapchat_app",
        "facebook_app",
    )
    private val trackedBlockSettingKeys = listOf(
        "instagram_reels",
        "instagram_explore",
        "youtube_shorts",
        "youtube_home_feed",
        "tiktok_for_you",
        "tiktok_live",
        "snapchat_spotlight",
        "snapchat_discover",
        "facebook_reels",
        "facebook_watch",
    )
    private val trackedUsagePackages = setOf(
        "com.instagram.android",
        "com.google.android.youtube",
        "com.zhiliaoapp.musically",
        "com.snapchat.android",
        "com.facebook.katana",
    )
    private val trackedUsagePackagePrefixes = setOf(
        "app.revanced.android.youtube",
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "lockin/accessibility",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(null)
                }
                "openUsageAccessSettings" -> {
                    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(null)
                }
                "isAccessibilityServiceEnabled" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                "isUsageAccessEnabled" -> {
                    result.success(isUsageAccessEnabled())
                }
                "getTodayUsageStats" -> {
                    result.success(getTodayUsageStats())
                }
                "setDailyTimeLimit" -> {
                    val settingKey = call.argument<String>("settingKey")
                    val minutes = call.argument<Int>("minutes")
                    if (settingKey == null) {
                        result.error("missing_setting_key", "settingKey is required", null)
                    } else {
                        setDailyTimeLimit(settingKey, minutes)
                        result.success(null)
                    }
                }
                "setBlockSetting" -> {
                    val settingKey = call.argument<String>("settingKey")
                    val value = call.argument<Boolean>("value")
                    if (settingKey == null || value == null) {
                        result.error("missing_block_setting", "settingKey and value are required", null)
                    } else {
                        setBlockSetting(settingKey, value)
                        result.success(null)
                    }
                }
                "getSavedBlockConfig" -> {
                    result.success(getSavedBlockConfig())
                }
                "getInstalledTrackedPackages" -> {
                    result.success(getInstalledTrackedPackages())
                }
                "getFirstInstallTime" -> {
                    result.success(
                        packageManager.getPackageInfo(packageName, 0).firstInstallTime,
                    )
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false

        val expectedService = ComponentName(
            this,
            AppGuardAccessibilityService::class.java,
        ).flattenToString()

        return enabledServices.split(':').any { service ->
            service.equals(expectedService, ignoreCase = true)
        }
    }

    private fun isUsageAccessEnabled(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            packageName,
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun getTodayUsageStats(): List<Map<String, Any>> {
        if (!isUsageAccessEnabled()) {
            return emptyList()
        }

        val calendar = Calendar.getInstance()
        val endTime = calendar.timeInMillis
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        val startTime = calendar.timeInMillis
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val stats = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            startTime,
            endTime,
        )

        return stats
            .filter { usage ->
                isTrackedUsagePackage(usage.packageName) &&
                    usage.totalTimeInForeground > 0
            }
            .map { usage ->
                mapOf(
                    "packageName" to usage.packageName,
                    "minutes" to (usage.totalTimeInForeground / 60000L).toInt(),
                )
            }
            .filter { usage -> usage["minutes"] as Int > 0 }
    }

    private fun getInstalledTrackedPackages(): List<String> {
        val launcherIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val launcherPackages = packageManager
            .queryIntentActivities(launcherIntent, 0)
            .mapNotNull { resolveInfo -> resolveInfo.activityInfo?.packageName }

        return launcherPackages.filter { packageName -> isTrackedUsagePackage(packageName) }
    }

    private fun isTrackedUsagePackage(packageName: String): Boolean {
        return trackedUsagePackages.contains(packageName) ||
            trackedUsagePackagePrefixes.any { prefix -> packageName.startsWith(prefix) }
    }

    private fun setDailyTimeLimit(settingKey: String, minutes: Int?) {
        getSharedPreferences(AppGuardAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .apply {
                if (minutes == null || minutes == 0) {
                    remove(settingKey)
                } else {
                    putInt(settingKey, minutes)
                }
            }
            .apply()
    }

    private fun setBlockSetting(settingKey: String, value: Boolean) {
        getSharedPreferences(AppGuardAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(settingKey, value)
            .apply()
    }

    private fun getSavedBlockConfig(): Map<String, Any> {
        val prefs = getSharedPreferences(AppGuardAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
        val dailyTimeLimits = trackedDailyTimeLimitKeys.associateWith { key ->
            if (prefs.contains(key)) prefs.getInt(key, 0) else null
        }
        val blockSettings = trackedBlockSettingKeys.associateWith { key ->
            prefs.getBoolean(key, false)
        }

        return mapOf(
            "dailyTimeLimits" to dailyTimeLimits,
            "blockSettings" to blockSettings,
        )
    }
}
