package com.example.tempus

import android.app.AppOpsManager
import android.app.usage.UsageEvents
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
import org.json.JSONArray
import org.json.JSONObject

open class MainActivity : FlutterActivity() {
    companion object {
        const val ACCESSIBILITY_CHANNEL_NAME = "tempus/accessibility"
    }

    private val scrollDayStatusesPrefKey = "scroll_day_statuses"
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
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ACCESSIBILITY_CHANNEL_NAME,
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
                "setScrollDayStatus" -> {
                    val dateKey = call.argument<String>("dateKey")
                    val status = call.argument<Int>("status")
                    if (dateKey == null || status == null) {
                        result.error(
                            "missing_scroll_day_status",
                            "dateKey and status are required",
                            null,
                        )
                    } else {
                        setScrollDayStatus(dateKey, status)
                        result.success(null)
                    }
                }
                "setBlockedWebsites" -> {
                    val blockedWebsites =
                        call.argument<List<Map<String, Any?>>>("blockedWebsites")
                    if (blockedWebsites == null) {
                        result.error(
                            "missing_blocked_websites",
                            "blockedWebsites is required",
                            null,
                        )
                    } else {
                        setBlockedWebsites(blockedWebsites)
                        result.success(null)
                    }
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

        val todayWindow = getTodayWindow()
        val foregroundMillisByPackage = getTrackedForegroundMillisByPackage(
            startTime = todayWindow.first,
            endTime = todayWindow.second,
        )

        return foregroundMillisByPackage.entries
            .map { entry ->
                mapOf(
                    "packageName" to entry.key,
                    "minutes" to (entry.value / 60000L).toInt(),
                )
            }
            .filter { usage -> (usage["minutes"] as Int) > 0 }
    }

    private fun getInstalledTrackedPackages(): List<String> {
        val launcherIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val launcherPackages = packageManager
            .queryIntentActivities(launcherIntent, 0)
            .mapNotNull { resolveInfo -> resolveInfo.activityInfo?.packageName }

        return launcherPackages.filter { packageName -> isTrackedUsagePackage(packageName) }
    }

    private fun isTrackedUsagePackage(packageName: String): Boolean {
        return packageName == "com.instagram.android" ||
            packageName == "com.google.android.youtube" ||
            packageName == "com.zhiliaoapp.musically" ||
            packageName == "com.snapchat.android" ||
            packageName == "com.facebook.katana" ||
            packageName.startsWith("app.revanced.android.youtube")
    }

    private fun getTodayWindow(): Pair<Long, Long> {
        val calendar = Calendar.getInstance()
        val endTime = calendar.timeInMillis
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        val startTime = calendar.timeInMillis
        return startTime to endTime
    }

    private fun getTrackedForegroundMillisByPackage(
        startTime: Long,
        endTime: Long,
    ): Map<String, Long> {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val usageEvents = usageStatsManager.queryEvents(startTime, endTime)
        val event = UsageEvents.Event()
        var currentForegroundPackage: String? = null
        var currentForegroundStart = 0L
        val totalsByPackage = mutableMapOf<String, Long>()

        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            val packageName = event.packageName ?: continue
            if (shouldIgnoreUsagePackage(packageName)) continue

            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED,
                UsageEvents.Event.MOVE_TO_FOREGROUND,
                -> {
                    if (
                        currentForegroundPackage != null &&
                        event.timeStamp > currentForegroundStart
                    ) {
                        addTrackedDuration(
                            totalsByPackage = totalsByPackage,
                            packageName = currentForegroundPackage!!,
                            durationMillis = event.timeStamp - currentForegroundStart,
                        )
                    }
                    currentForegroundPackage = packageName
                    currentForegroundStart = event.timeStamp
                }

                UsageEvents.Event.ACTIVITY_PAUSED,
                UsageEvents.Event.MOVE_TO_BACKGROUND,
                -> {
                    if (
                        currentForegroundPackage == packageName &&
                        event.timeStamp > currentForegroundStart
                    ) {
                        addTrackedDuration(
                            totalsByPackage = totalsByPackage,
                            packageName = packageName,
                            durationMillis = event.timeStamp - currentForegroundStart,
                        )
                        currentForegroundPackage = null
                        currentForegroundStart = 0L
                    }
                }
            }
        }

        if (currentForegroundPackage != null && endTime > currentForegroundStart) {
            addTrackedDuration(
                totalsByPackage = totalsByPackage,
                packageName = currentForegroundPackage!!,
                durationMillis = endTime - currentForegroundStart,
            )
        }

        return totalsByPackage
    }

    private fun addTrackedDuration(
        totalsByPackage: MutableMap<String, Long>,
        packageName: String,
        durationMillis: Long,
    ) {
        if (!isTrackedUsagePackage(packageName) || durationMillis <= 0L) return
        totalsByPackage[packageName] = (totalsByPackage[packageName] ?: 0L) + durationMillis
    }

    private fun shouldIgnoreUsagePackage(packageName: String): Boolean {
        return packageName == this.packageName ||
            packageName == "com.android.systemui"
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
        val scrollDayStatuses = getScrollDayStatuses()
        val blockedWebsites = getBlockedWebsites()

        return mapOf(
            "dailyTimeLimits" to dailyTimeLimits,
            "blockSettings" to blockSettings,
            "scrollDayStatuses" to scrollDayStatuses,
            "blockedWebsites" to blockedWebsites,
        )
    }

    private fun setScrollDayStatus(dateKey: String, status: Int) {
        val currentStatuses = getScrollDayStatuses().toMutableMap()
        currentStatuses[dateKey] = status
        val serialized = JSONObject().apply {
            currentStatuses.forEach { (key, value) ->
                put(key, value)
            }
        }.toString()

        getSharedPreferences(AppGuardAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(scrollDayStatusesPrefKey, serialized)
            .apply()
    }

    private fun getScrollDayStatuses(): Map<String, Int> {
        val prefs = getSharedPreferences(AppGuardAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
        val serialized = prefs.getString(scrollDayStatusesPrefKey, null) ?: return emptyMap()
        val jsonObject = JSONObject(serialized)
        val result = mutableMapOf<String, Int>()
        val keys = jsonObject.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            result[key] = jsonObject.optInt(key)
        }
        return result
    }

    private fun setBlockedWebsites(blockedWebsites: List<Map<String, Any?>>) {
        val serialized = JSONArray().apply {
            blockedWebsites.forEach { website ->
                put(
                    JSONObject().apply {
                        put("domain", website["domain"] as? String ?: "")
                        put("blockedSince", website["blockedSince"] as? Long ?: 0L)
                    },
                )
            }
        }.toString()

        getSharedPreferences(AppGuardAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString("blocked_websites", serialized)
            .apply()
    }

    private fun getBlockedWebsites(): List<Map<String, Any>> {
        val prefs = getSharedPreferences(AppGuardAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
        val serialized = prefs.getString("blocked_websites", null) ?: return emptyList()
        val jsonArray = JSONArray(serialized)

        return List(jsonArray.length()) { index ->
            val entry = jsonArray.getJSONObject(index)
            mapOf(
                "domain" to entry.optString("domain"),
                "blockedSince" to entry.optLong("blockedSince"),
            )
        }
    }
}
