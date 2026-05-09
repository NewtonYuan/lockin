package com.prestige.tempus

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Bundle
import android.provider.Settings
import android.os.Process
import android.util.Base64
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.Calendar
import java.util.concurrent.Executors
import org.json.JSONArray
import org.json.JSONObject

open class MainActivity : FlutterActivity() {
    companion object {
        const val ACCESSIBILITY_CHANNEL_NAME = "tempus/accessibility"
    }

    private val scrollDayStatusesPrefKey = "scroll_day_statuses"
    private val customTrackedAppsPrefKey = "custom_tracked_apps"
    private val appLoadingExecutor = Executors.newSingleThreadExecutor()
    private val builtInTrackedDailyTimeLimitKeys = listOf(
        "instagram_app",
        "youtube_app",
    )
    private val trackedBlockSettingKeys = listOf(
        "instagram_pause_on_open",
        "instagram_reels",
        "instagram_reels_dms",
        "instagram_explore",
        "youtube_pause_on_open",
        "youtube_shorts",
        "youtube_home_feed",
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ACCESSIBILITY_CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openAccessibilitySettings" -> {
                    markAwaitingAccessibilityEnable()
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
                "consumeAccessibilityEnabledSuccess" -> {
                    result.success(consumeAccessibilityEnabledSuccess())
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
                "getInstalledApps" -> {
                    appLoadingExecutor.execute {
                        runCatching {
                            getInstalledApps()
                        }.onSuccess { installedApps ->
                            runOnUiThread {
                                result.success(installedApps)
                            }
                        }.onFailure { error ->
                            runOnUiThread {
                                result.error(
                                    "installed_apps_failed",
                                    error.message ?: "Failed to load installed apps",
                                    null,
                                )
                            }
                        }
                    }
                }
                "setCustomTrackedApps" -> {
                    val customTrackedApps =
                        call.argument<List<Map<String, Any?>>>("customTrackedApps")
                    if (customTrackedApps == null) {
                        result.error(
                            "missing_custom_tracked_apps",
                            "customTrackedApps is required",
                            null,
                        )
                    } else {
                        setCustomTrackedApps(customTrackedApps)
                        result.success(null)
                    }
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

    private fun markAwaitingAccessibilityEnable() {
        getSharedPreferences(AppGuardAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(AppGuardAccessibilityService.AWAITING_ACCESSIBILITY_ENABLE_PREF_KEY, true)
            .apply()
    }

    private fun consumeAccessibilityEnabledSuccess(): Boolean {
        val prefs = getSharedPreferences(AppGuardAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
        val shouldShow = prefs.getBoolean(
            AppGuardAccessibilityService.ACCESSIBILITY_ENABLED_SUCCESS_PREF_KEY,
            false,
        )
        if (shouldShow) {
            prefs.edit()
                .putBoolean(AppGuardAccessibilityService.ACCESSIBILITY_ENABLED_SUCCESS_PREF_KEY, false)
                .apply()
        }
        return shouldShow
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

    private fun getInstalledApps(): List<Map<String, Any>> {
        val launcherIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return packageManager
            .queryIntentActivities(launcherIntent, 0)
            .mapNotNull { resolveInfo ->
                val activityInfo = resolveInfo.activityInfo ?: return@mapNotNull null
                val appPackageName = activityInfo.packageName ?: return@mapNotNull null
                if (appPackageName == packageName) return@mapNotNull null
                mapOf(
                    "appName" to resolveInfo.loadLabel(packageManager).toString(),
                    "packageName" to appPackageName,
                    "iconBytes" to encodeDrawableToPngBytes(
                        resolveInfo.loadIcon(packageManager),
                    ),
                )
            }
            .distinctBy { app -> app["packageName"] }
            .sortedBy { app -> (app["appName"] as? String)?.lowercase() ?: "" }
    }

    private fun isTrackedUsagePackage(packageName: String): Boolean {
        return getTrackedAppLimits().any { appLimit -> appLimit.matches(packageName) }
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
        val dailyTimeLimits = getTrackedDailyTimeLimitKeys().associateWith { key ->
            if (prefs.contains(key)) prefs.getInt(key, 0) else null
        }
        val blockSettings = getTrackedBlockSettingKeys().associateWith { key ->
            prefs.getBoolean(key, false)
        }
        val scrollDayStatuses = getScrollDayStatuses()
        val blockedWebsites = getBlockedWebsites()
        val customTrackedApps = getCustomTrackedApps()

        return mapOf(
            "dailyTimeLimits" to dailyTimeLimits,
            "blockSettings" to blockSettings,
            "scrollDayStatuses" to scrollDayStatuses,
            "blockedWebsites" to blockedWebsites,
            "customTrackedApps" to customTrackedApps,
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

    private fun setCustomTrackedApps(customTrackedApps: List<Map<String, Any?>>) {
        val serialized = JSONArray().apply {
            customTrackedApps.forEach { app ->
                put(
                    JSONObject().apply {
                        put("appName", app["appName"] as? String ?: "")
                        put("packageName", app["packageName"] as? String ?: "")
                        put(
                            "iconBytes",
                            (app["iconBytes"] as? ByteArray)?.let { iconBytes ->
                                Base64.encodeToString(iconBytes, Base64.NO_WRAP)
                            },
                        )
                    },
                )
            }
        }.toString()

        getSharedPreferences(AppGuardAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(customTrackedAppsPrefKey, serialized)
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

    private fun getCustomTrackedApps(): List<Map<String, Any>> {
        val prefs = getSharedPreferences(AppGuardAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
        val serialized = prefs.getString(customTrackedAppsPrefKey, null) ?: return emptyList()
        val jsonArray = JSONArray(serialized)

        return List<Map<String, Any>>(jsonArray.length()) { index ->
            val entry = jsonArray.getJSONObject(index)
            buildMap<String, Any> {
                put("appName", entry.optString("appName"))
                put("packageName", entry.optString("packageName"))
                put(
                    "iconBytes",
                    entry.optString("iconBytes")
                        .takeIf { it.isNotBlank() }
                        ?.let { encoded -> Base64.decode(encoded, Base64.DEFAULT) }
                        ?: ByteArray(0),
                )
            }
        }.filter { entry ->
            !(entry["appName"] as? String).isNullOrBlank() &&
                !(entry["packageName"] as? String).isNullOrBlank()
        }
    }

    private fun getTrackedDailyTimeLimitKeys(): List<String> {
        return buildList {
            addAll(builtInTrackedDailyTimeLimitKeys)
            addAll(
                getCustomTrackedApps().mapNotNull { app ->
                    (app["packageName"] as? String)
                        ?.takeIf { it.isNotBlank() }
                        ?.let(::customTrackedAppSettingKey)
                },
            )
        }
    }

    private fun getTrackedBlockSettingKeys(): List<String> {
        return buildList {
            addAll(trackedBlockSettingKeys)
            addAll(
                getCustomTrackedApps().mapNotNull { app ->
                    (app["packageName"] as? String)
                        ?.takeIf { it.isNotBlank() }
                        ?.let(::customTrackedAppPauseOnOpenSettingKey)
                },
            )
        }
    }

    private fun getTrackedAppLimits(): List<AppLimit> {
        return buildList {
            addAll(builtInTrackedAppLimits)
            addAll(
                getCustomTrackedApps().mapNotNull { app ->
                    val appPackageName = (app["packageName"] as? String)
                        ?.takeIf { it.isNotBlank() }
                        ?: return@mapNotNull null
                    AppLimit(
                        settingKey = customTrackedAppSettingKey(appPackageName),
                        packageNames = setOf(appPackageName),
                    )
                },
            )
        }
    }

    private fun customTrackedAppSettingKey(packageName: String): String {
        return "custom_app_" + packageName.replace(Regex("[^A-Za-z0-9]+"), "_")
    }

    private fun customTrackedAppPauseOnOpenSettingKey(packageName: String): String {
        return "custom_app_pause_on_open_" + packageName.replace(Regex("[^A-Za-z0-9]+"), "_")
    }

    private fun encodeDrawableToPngBytes(drawable: Drawable): ByteArray {
        val bitmap = when (drawable) {
            is BitmapDrawable -> drawable.bitmap
            else -> {
                val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 96
                val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 96
                Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).also { bitmap ->
                    val canvas = Canvas(bitmap)
                    drawable.setBounds(0, 0, canvas.width, canvas.height)
                    drawable.draw(canvas)
                }
            }
        }
        return ByteArrayOutputStream().use { outputStream ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
            outputStream.toByteArray()
        }
    }

    override fun onDestroy() {
        appLoadingExecutor.shutdownNow()
        super.onDestroy()
    }

    private data class AppLimit(
        val settingKey: String,
        val packageNames: Set<String>,
        val packagePrefixes: Set<String> = emptySet(),
    ) {
        fun matches(packageName: String): Boolean {
            return packageNames.contains(packageName) ||
                packagePrefixes.any { prefix -> packageName.startsWith(prefix) }
        }
    }

    private val builtInTrackedAppLimits = listOf(
        AppLimit(
            settingKey = "instagram_app",
            packageNames = setOf("com.instagram.android"),
        ),
        AppLimit(
            settingKey = "youtube_app",
            packageNames = setOf("com.google.android.youtube"),
            packagePrefixes = setOf("app.revanced.android.youtube"),
        ),
    )
}
