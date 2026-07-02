package com.prestige.tempus

import android.app.ActivityManager
import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.os.Process
import android.util.Base64
import androidx.activity.enableEdgeToEdge
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.Calendar
import java.util.concurrent.Executors
import org.json.JSONArray
import org.json.JSONObject

open class MainActivity : FlutterFragmentActivity() {
    companion object {
        const val ACCESSIBILITY_CHANNEL_NAME = "tempus/accessibility"
        private const val PENDING_SHARED_WEBSITE_PREF_KEY = "pending_shared_website"
        private const val ONBOARDING_COMPLETED_PREF_KEY = "onboarding_completed"
        private const val ACCESSIBILITY_WATCH_INTERVAL_MILLIS = 500L
        private const val USAGE_ACCESS_WATCH_INTERVAL_MILLIS = 500L
        private const val DAY_IN_MILLIS = 24L * 60L * 60L * 1000L
        private const val BLOCK_EVENT_DEDUPLICATION_WINDOW_MILLIS = 2000L
    }

    private data class ForegroundUsageSummary(
        val totalsByPackage: Map<String, Long>,
        val hourlyTrackedMinutes: List<Int>,
        val hourlyTrackedMinutesByPackage: Map<String, List<Int>>,
    )

    private val scrollDayStatusesPrefKey = "scroll_day_statuses"
    private val customTrackedAppsPrefKey = "custom_tracked_apps"
    private val appLoadingExecutor = Executors.newSingleThreadExecutor()
    private val statisticsLoadingExecutor = Executors.newSingleThreadExecutor()
    private val accessibilityWatcherHandler = Handler(Looper.getMainLooper())
    private val accessibilityEnableWatcher = object : Runnable {
        override fun run() {
            val prefs = getSharedPreferences(AppGuardAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
            val awaitingEnable = prefs.getBoolean(
                AppGuardAccessibilityService.AWAITING_ACCESSIBILITY_ENABLE_PREF_KEY,
                false,
            )
            if (!awaitingEnable) return
            if (isAccessibilityServiceEnabled()) {
                prefs.edit()
                    .putBoolean(AppGuardAccessibilityService.AWAITING_ACCESSIBILITY_ENABLE_PREF_KEY, false)
                    .putBoolean(AppGuardAccessibilityService.ACCESSIBILITY_ENABLED_SUCCESS_PREF_KEY, true)
                    .apply()
                relaunchAppToForeground()
                return
            }
            accessibilityWatcherHandler.postDelayed(
                this,
                ACCESSIBILITY_WATCH_INTERVAL_MILLIS,
            )
        }
    }
    private val usageAccessWatcherHandler = Handler(Looper.getMainLooper())
    private val usageAccessEnableWatcher = object : Runnable {
        override fun run() {
            val prefs = getSharedPreferences(AppGuardAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
            val awaitingEnable = prefs.getBoolean(
                AppGuardAccessibilityService.AWAITING_USAGE_ACCESS_ENABLE_PREF_KEY,
                false,
            )
            if (!awaitingEnable) return
            if (isUsageAccessEnabled()) {
                prefs.edit()
                    .putBoolean(AppGuardAccessibilityService.AWAITING_USAGE_ACCESS_ENABLE_PREF_KEY, false)
                    .putBoolean(AppGuardAccessibilityService.USAGE_ACCESS_ENABLED_SUCCESS_PREF_KEY, true)
                    .apply()
                relaunchAppToForeground()
                return
            }
            usageAccessWatcherHandler.postDelayed(
                this,
                USAGE_ACCESS_WATCH_INTERVAL_MILLIS,
            )
        }
    }
    private val builtInTrackedDailyTimeLimitKeys = listOf(
        "instagram_app",
        "snapchat_app",
        "youtube_app",
    )
    private val trackedBlockSettingKeys = listOf(
        "instagram_pause_on_open",
        "instagram_reels",
        "instagram_reels_dms",
        "instagram_explore",
        "instagram_hide_explore_feed",
        "snapchat_pause_on_open",
        "snapchat_spotlight",
        "youtube_pause_on_open",
        "youtube_shorts",
        "youtube_home_feed",
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        handleIncomingShareIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        startAccessibilityEnableWatcherIfNeeded()
        startUsageAccessEnableWatcherIfNeeded()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIncomingShareIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ACCESSIBILITY_CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openAccessibilitySettings" -> {
                    if (isAccessibilityServiceEnabled()) {
                        clearAccessibilityEnableWatch()
                    } else {
                        markAwaitingAccessibilityEnable()
                    }
                    startActivity(
                        Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        },
                    )
                    result.success(null)
                }
                "openUsageAccessSettings" -> {
                    if (isUsageAccessEnabled()) {
                        clearUsageAccessEnableWatch()
                    } else {
                        markAwaitingUsageAccessEnable()
                    }
                    openUsageAccessSettings()
                    result.success(null)
                }
                "openOverlayPermissionSettings" -> {
                    openOverlayPermissionSettings()
                    result.success(null)
                }
                "isAccessibilityServiceEnabled" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                "isOverlayPermissionEnabled" -> {
                    result.success(isOverlayPermissionEnabled())
                }
                "consumeAccessibilityEnabledSuccess" -> {
                    result.success(consumeAccessibilityEnabledSuccess())
                }
                "consumeUsageAccessEnabledSuccess" -> {
                    result.success(consumeUsageAccessEnabledSuccess())
                }
                "consumeSharedWebsite" -> {
                    result.success(consumePendingSharedWebsite())
                }
                "getOnboardingCompleted" -> {
                    result.success(getOnboardingCompleted())
                }
                "setOnboardingCompleted" -> {
                    val completed = call.argument<Boolean>("completed")
                    if (completed == null) {
                        result.error("missing_onboarding_completed", "completed is required", null)
                    } else {
                        setOnboardingCompleted(completed)
                        result.success(null)
                    }
                }
                "isUsageAccessEnabled" -> {
                    result.success(isUsageAccessEnabled())
                }
                "getTodayUsageStats" -> {
                    result.success(getTodayUsageStats())
                }
                "getTodayAllAppUsageStats" -> {
                    result.success(getTodayAllAppUsageStats())
                }
                "getTodayScrollHeuristicMetrics" -> {
                    result.success(getTodayScrollHeuristicMetrics())
                }
                "getStatisticsData" -> {
                    statisticsLoadingExecutor.execute {
                        runCatching {
                            getStatisticsData()
                        }.onSuccess { statisticsData ->
                            runOnUiThread {
                                result.success(statisticsData)
                            }
                        }.onFailure { error ->
                            runOnUiThread {
                                result.error(
                                    "statistics_data_failed",
                                    error.message ?: "Failed to load statistics data",
                                    null,
                                )
                            }
                        }
                    }
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
                "setPauseDurationSeconds" -> {
                    val seconds = call.argument<Int>("seconds")
                    if (seconds == null) {
                        result.error("missing_pause_duration_seconds", "seconds is required", null)
                    } else {
                        setPauseDurationSeconds(seconds)
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
                "openWebsite" -> {
                    val url = call.argument<String>("url")
                    if (url.isNullOrBlank()) {
                        result.error("missing_url", "url is required", null)
                    } else {
                        openWebsite(url)
                        result.success(null)
                    }
                }
                "shareText" -> {
                    val text = call.argument<String>("text")
                    if (text.isNullOrBlank()) {
                        result.error("missing_text", "text is required", null)
                    } else {
                        shareText(text)
                        result.success(null)
                    }
                }
                "getInstalledTrackedPackages" -> {
                    result.success(getInstalledTrackedPackages())
                }
                "getInstalledTrackedApps" -> {
                    result.success(getInstalledTrackedApps())
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

    private fun openUsageAccessSettings() {
        val packageUri = Uri.fromParts("package", packageName, null)
        val packageSpecificIntent =
            Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                data = packageUri
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        val genericIntent =
            Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

        when {
            canResolveIntent(packageSpecificIntent) -> startActivity(packageSpecificIntent)
            canResolveIntent(genericIntent) -> startActivity(genericIntent)
            else -> {
                val appDetailsIntent =
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = packageUri
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                startActivity(appDetailsIntent)
            }
        }
    }

    private fun canResolveIntent(intent: Intent): Boolean {
        return intent.resolveActivity(packageManager) != null
    }

    private fun markAwaitingAccessibilityEnable() {
        getSharedPreferences(AppGuardAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(AppGuardAccessibilityService.AWAITING_ACCESSIBILITY_ENABLE_PREF_KEY, true)
            .apply()
        startAccessibilityEnableWatcherIfNeeded()
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

    private fun markAwaitingUsageAccessEnable() {
        getSharedPreferences(AppGuardAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(AppGuardAccessibilityService.AWAITING_USAGE_ACCESS_ENABLE_PREF_KEY, true)
            .apply()
        AppGuardAccessibilityService.beginUsageAccessEnableWatch()
        startUsageAccessEnableWatcherIfNeeded()
    }

    private fun consumeUsageAccessEnabledSuccess(): Boolean {
        val prefs = getSharedPreferences(AppGuardAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
        val shouldShow = prefs.getBoolean(
            AppGuardAccessibilityService.USAGE_ACCESS_ENABLED_SUCCESS_PREF_KEY,
            false,
        )
        if (shouldShow) {
            prefs.edit()
                .putBoolean(AppGuardAccessibilityService.USAGE_ACCESS_ENABLED_SUCCESS_PREF_KEY, false)
                .apply()
        }
        return shouldShow
    }

    private fun startUsageAccessEnableWatcherIfNeeded() {
        val prefs = getSharedPreferences(AppGuardAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
        val awaitingEnable = prefs.getBoolean(
            AppGuardAccessibilityService.AWAITING_USAGE_ACCESS_ENABLE_PREF_KEY,
            false,
        )
        if (!awaitingEnable) return
        usageAccessWatcherHandler.removeCallbacks(usageAccessEnableWatcher)
        usageAccessWatcherHandler.post(usageAccessEnableWatcher)
    }

    private fun startAccessibilityEnableWatcherIfNeeded() {
        val prefs = getSharedPreferences(AppGuardAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
        val awaitingEnable = prefs.getBoolean(
            AppGuardAccessibilityService.AWAITING_ACCESSIBILITY_ENABLE_PREF_KEY,
            false,
        )
        if (!awaitingEnable) return
        accessibilityWatcherHandler.removeCallbacks(accessibilityEnableWatcher)
        accessibilityWatcherHandler.post(accessibilityEnableWatcher)
    }

    private fun clearAccessibilityEnableWatch() {
        accessibilityWatcherHandler.removeCallbacks(accessibilityEnableWatcher)
        getSharedPreferences(AppGuardAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(AppGuardAccessibilityService.AWAITING_ACCESSIBILITY_ENABLE_PREF_KEY, false)
            .apply()
    }

    private fun clearUsageAccessEnableWatch() {
        usageAccessWatcherHandler.removeCallbacks(usageAccessEnableWatcher)
        getSharedPreferences(AppGuardAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(AppGuardAccessibilityService.AWAITING_USAGE_ACCESS_ENABLE_PREF_KEY, false)
            .apply()
    }

    private fun relaunchAppToForeground() {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val existingTask = activityManager.appTasks.firstOrNull { appTask ->
            appTask.taskInfo.baseIntent.component?.packageName == packageName
        }
        if (existingTask != null) {
            runCatching {
                existingTask.moveToFront()
            }.onSuccess {
                return
            }
        }

        val intent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        } ?: return

        startActivity(intent)
    }

    private fun handleIncomingShareIntent(intent: Intent?) {
        if (intent?.action != Intent.ACTION_SEND) return
        val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
            ?: intent.getStringExtra(Intent.EXTRA_SUBJECT)
            ?: return
        if (sharedText.isBlank()) return
        getSharedPreferences(AppGuardAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(PENDING_SHARED_WEBSITE_PREF_KEY, sharedText)
            .apply()
    }

    private fun consumePendingSharedWebsite(): String? {
        val prefs = getSharedPreferences(AppGuardAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
        val sharedWebsite = prefs.getString(PENDING_SHARED_WEBSITE_PREF_KEY, null)
        if (!sharedWebsite.isNullOrBlank()) {
            prefs.edit()
                .remove(PENDING_SHARED_WEBSITE_PREF_KEY)
                .apply()
        }
        return sharedWebsite
    }

    private fun getOnboardingCompleted(): Boolean {
        return getSharedPreferences(AppGuardAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(ONBOARDING_COMPLETED_PREF_KEY, false)
    }

    private fun setOnboardingCompleted(completed: Boolean) {
        getSharedPreferences(AppGuardAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(ONBOARDING_COMPLETED_PREF_KEY, completed)
            .apply()
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

    private fun isOverlayPermissionEnabled(): Boolean {
        return Settings.canDrawOverlays(this)
    }

    private fun openOverlayPermissionSettings() {
        startActivity(
            Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName"),
            ).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
        )
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

    private fun getTodayAllAppUsageStats(): List<Map<String, Any>> {
        if (!isUsageAccessEnabled()) {
            return emptyList()
        }

        val todayWindow = getTodayWindow()
        val foregroundMillisByPackage = getAllForegroundMillisByPackage(
            startTime = todayWindow.first,
            endTime = todayWindow.second,
        )

        return foregroundMillisByPackage.entries
            .mapNotNull { entry ->
                val minutes = (entry.value / 60000L).toInt()
                if (minutes <= 0) return@mapNotNull null
                val appName = try {
                    val applicationInfo = packageManager.getApplicationInfo(entry.key, 0)
                    packageManager.getApplicationLabel(applicationInfo).toString()
                } catch (_: Exception) {
                    entry.key
                }
                mapOf(
                    "appName" to appName,
                    "packageName" to entry.key,
                    "minutes" to minutes,
                )
            }
            .sortedByDescending { entry -> entry["minutes"] as Int }
    }

    private fun getTodayScrollHeuristicMetrics(): Map<String, Int> {
        if (!isUsageAccessEnabled()) {
            return mapOf(
                "shortFormBypassMinutes" to 0,
                "trackedLimitOverageMinutes" to 0,
            )
        }

        val todayWindow = getTodayWindow()
        val shortFormBypassMillis = getShortFormBypassForegroundMillis(
            startTime = todayWindow.first,
            endTime = todayWindow.second,
        )
        val trackedLimitOverageMillis = getTrackedLimitOverageMillis(
            startTime = todayWindow.first,
            endTime = todayWindow.second,
        )

        return mapOf(
            "shortFormBypassMinutes" to (shortFormBypassMillis / 60000L).toInt(),
            "trackedLimitOverageMinutes" to (trackedLimitOverageMillis / 60000L).toInt(),
        )
    }

    private fun getStatisticsData(): Map<String, Any> {
        val todayWindow = getTodayWindow()
        val todayStart = todayWindow.first
        val now = todayWindow.second
        val last7Start = startOfDay(todayStart - (6L * DAY_IN_MILLIS))
        val last30Start = startOfDay(todayStart - (29L * DAY_IN_MILLIS))
        val usageEnabled = isUsageAccessEnabled()
        val allAppDefinitions = getStatisticsAppDefinitions()
        val statsEvents = getStatsEvents().filter { event ->
            event.timestamp in last30Start until now
        }
        val usageByPackageLast30 = if (usageEnabled) {
            getAllForegroundMillisByPackage(last30Start, now)
        } else {
            emptyMap()
        }
        val appDefinitions = allAppDefinitions.filter { definition ->
            trackedMinutesForAppDefinition(definition, usageByPackageLast30) > 0 ||
                statsEvents.any { event -> definition.matches(event.packageName) }
        }

        val dailySummaries = mutableListOf<Map<String, Any>>()
        val appDailyMinutes = appDefinitions.associate { definition ->
            definition.id to mutableListOf<Int>()
        }
        val appDailySessionCounts = appDefinitions.associate { definition ->
            definition.id to mutableListOf<Int>()
        }
        val appDailyLongestSessionMinutes = appDefinitions.associate { definition ->
            definition.id to mutableListOf<Int>()
        }

        for (offset in 29 downTo 0) {
            val dayStart = startOfDay(todayStart - (offset.toLong() * DAY_IN_MILLIS))
            val dayEnd = minOf(dayStart + DAY_IN_MILLIS, now)
            val foregroundUsageSummary = if (usageEnabled) {
                getForegroundUsageSummary(dayStart, dayEnd)
            } else {
                ForegroundUsageSummary(emptyMap(), List(24) { 0 }, emptyMap())
            }
            val usageByPackage = foregroundUsageSummary.totalsByPackage
            val dayEvents = statsEvents.filter { event ->
                event.timestamp in dayStart until dayEnd
            }
            val trackedMinutes = usageByPackage.values.sumOf { millis ->
                (millis / 60000L).toInt()
            }
            val byType = summarizeEventsByType(dayEvents)
            val sessionStats = if (usageEnabled) {
                getForegroundSessionStatsForDefinitions(appDefinitions, dayStart, dayEnd)
            } else {
                SessionStats(emptyMap(), emptyMap())
            }
            val appEventsById = appDefinitions.associate { definition ->
                definition.id to dayEvents.filter { event -> definition.matches(event.packageName) }
            }
            val bypassMinutesByAppIdForDay = if (usageEnabled) {
                getShortFormBypassMinutesByStatisticsAppId(dayStart, dayEnd)
            } else {
                emptyMap()
            }
            val timeOfDayBlocks = emptyTimeOfDayCounts().toMutableMap()
            val timeOfDayBypasses = emptyTimeOfDayCounts().toMutableMap()
            for (event in dayEvents) {
                val bucketLabel = timeOfDayBucketLabel(event.timestamp)
                if (isBlockEventType(event.type)) {
                    timeOfDayBlocks[bucketLabel] = (timeOfDayBlocks[bucketLabel] ?: 0) + 1
                }
                if (isBypassEventType(event.type)) {
                    timeOfDayBypasses[bucketLabel] = (timeOfDayBypasses[bucketLabel] ?: 0) + 1
                }
            }
            val appMinutes = buildMap<String, Int> {
                for (definition in appDefinitions) {
                    val minutes = trackedMinutesForAppDefinition(definition, usageByPackage)
                    put(definition.id, minutes)
                    appDailyMinutes[definition.id]?.add(minutes)
                    appDailySessionCounts[definition.id]?.add(
                        sessionStats.countsByAppId[definition.id] ?: 0,
                    )
                    appDailyLongestSessionMinutes[definition.id]?.add(
                        sessionStats.longestSessionMinutesByAppId[definition.id] ?: 0,
                    )
                }
            }
            val appSessionCounts = buildMap<String, Int> {
                for (definition in appDefinitions) {
                    put(definition.id, sessionStats.countsByAppId[definition.id] ?: 0)
                }
            }
            val appHourlyTrackedMinutes = buildMap<String, List<Int>> {
                for (definition in appDefinitions) {
                    put(
                        definition.id,
                        hourlyTrackedMinutesForAppDefinition(
                            definition = definition,
                            hourlyTrackedMinutesByPackage =
                                foregroundUsageSummary.hourlyTrackedMinutesByPackage,
                        ),
                    )
                }
            }
            val appLongestSessionMinutes = buildMap<String, Int> {
                for (definition in appDefinitions) {
                    put(definition.id, sessionStats.longestSessionMinutesByAppId[definition.id] ?: 0)
                }
            }
            val appReelsBlocks = buildMap<String, Int> {
                for (definition in appDefinitions) {
                    put(
                        definition.id,
                        appEventsById[definition.id].orEmpty().count { event ->
                            event.type == AppGuardAccessibilityService.STATS_EVENT_REELS_BLOCK
                        },
                    )
                }
            }
            val appShortsBlocks = buildMap<String, Int> {
                for (definition in appDefinitions) {
                    put(
                        definition.id,
                        appEventsById[definition.id].orEmpty().count { event ->
                            event.type == AppGuardAccessibilityService.STATS_EVENT_SHORTS_BLOCK
                        },
                    )
                }
            }
            val appSpotlightBlocks = buildMap<String, Int> {
                for (definition in appDefinitions) {
                    put(
                        definition.id,
                        appEventsById[definition.id].orEmpty().count { event ->
                            event.type == AppGuardAccessibilityService.STATS_EVENT_SPOTLIGHT_BLOCK
                        },
                    )
                }
            }
            val appPauseOnOpenPrompts = buildMap<String, Int> {
                for (definition in appDefinitions) {
                    put(
                        definition.id,
                        appEventsById[definition.id].orEmpty().count { event ->
                            event.type == AppGuardAccessibilityService.STATS_EVENT_PAUSE_ON_OPEN_PROMPT
                        },
                    )
                }
            }
            val appDailyLimitHits = buildMap<String, Int> {
                for (definition in appDefinitions) {
                    put(
                        definition.id,
                        appEventsById[definition.id].orEmpty().count { event ->
                            event.type == AppGuardAccessibilityService.STATS_EVENT_DAILY_LIMIT_HIT
                        },
                    )
                }
            }
            val appBypasses = buildMap<String, Int> {
                for (definition in appDefinitions) {
                    put(
                        definition.id,
                        appEventsById[definition.id].orEmpty().count { event ->
                            event.type == AppGuardAccessibilityService.STATS_EVENT_SHORT_FORM_BYPASS ||
                                event.type == AppGuardAccessibilityService.STATS_EVENT_PAUSE_ON_OPEN_BYPASS ||
                                event.type == AppGuardAccessibilityService.STATS_EVENT_DAILY_LIMIT_BYPASS
                        },
                    )
                }
            }
            val appBypassedMinutes = buildMap<String, Int> {
                for (definition in appDefinitions) {
                    put(definition.id, bypassMinutesByAppIdForDay[definition.id] ?: 0)
                }
            }

            dailySummaries.add(
                mapOf(
                    "dateKey" to dateKeyForMillis(dayStart),
                    "trackedMinutes" to trackedMinutes,
                    "hourlyTrackedMinutes" to foregroundUsageSummary.hourlyTrackedMinutes,
                    "blocks" to countBlockEvents(dayEvents),
                    "bypasses" to countBypassEvents(dayEvents),
                    "reelsBlocks" to byType.getValue(AppGuardAccessibilityService.STATS_EVENT_REELS_BLOCK),
                    "shortsBlocks" to byType.getValue(AppGuardAccessibilityService.STATS_EVENT_SHORTS_BLOCK),
                    "spotlightBlocks" to byType.getValue(AppGuardAccessibilityService.STATS_EVENT_SPOTLIGHT_BLOCK),
                    "websiteBlocks" to byType.getValue(AppGuardAccessibilityService.STATS_EVENT_WEBSITE_BLOCK),
                    "pauseOnOpenPrompts" to byType.getValue(AppGuardAccessibilityService.STATS_EVENT_PAUSE_ON_OPEN_PROMPT),
                    "dailyLimitHits" to byType.getValue(AppGuardAccessibilityService.STATS_EVENT_DAILY_LIMIT_HIT),
                    "shortFormBypasses" to byType.getValue(AppGuardAccessibilityService.STATS_EVENT_SHORT_FORM_BYPASS),
                    "websiteBypasses" to byType.getValue(AppGuardAccessibilityService.STATS_EVENT_WEBSITE_BYPASS),
                    "pauseOnOpenBypasses" to byType.getValue(AppGuardAccessibilityService.STATS_EVENT_PAUSE_ON_OPEN_BYPASS),
                    "dailyLimitBypasses" to byType.getValue(AppGuardAccessibilityService.STATS_EVENT_DAILY_LIMIT_BYPASS),
                    "sessionCount" to appSessionCounts.values.sum(),
                    "longestSessionMinutes" to (appLongestSessionMinutes.values.maxOrNull() ?: 0),
                    "appMinutes" to appMinutes,
                    "appHourlyTrackedMinutes" to appHourlyTrackedMinutes,
                    "appSessionCounts" to appSessionCounts,
                    "appLongestSessionMinutes" to appLongestSessionMinutes,
                    "appReelsBlocks" to appReelsBlocks,
                    "appShortsBlocks" to appShortsBlocks,
                    "appSpotlightBlocks" to appSpotlightBlocks,
                    "appPauseOnOpenPrompts" to appPauseOnOpenPrompts,
                    "appDailyLimitHits" to appDailyLimitHits,
                    "appBypasses" to appBypasses,
                    "appBypassedMinutes" to appBypassedMinutes,
                    "timeOfDayBlocks" to timeOfDayBlocks,
                    "timeOfDayBypasses" to timeOfDayBypasses,
                ),
            )
        }

        val todayUsageByPackage = if (usageEnabled) {
            getAllForegroundMillisByPackage(todayStart, now)
        } else {
            emptyMap()
        }
        val todayEvents = statsEvents.filter { event ->
            event.timestamp in todayStart until now
        }
        val weekEvents = statsEvents.filter { event ->
            event.timestamp in last7Start until now
        }
        val todayTrackedMinutes = todayUsageByPackage.values.sumOf { millis ->
            (millis / 60000L).toInt()
        }
        val weekTrackedMinutes = dailySummaries
            .takeLast(7)
            .sumOf { summary -> summary["trackedMinutes"] as Int }
        val averageDailyTrackedMinutes = weekTrackedMinutes / 7.0
        val todayBypassMinutes = if (usageEnabled) {
            (getShortFormBypassForegroundMillis(todayStart, now) / 60000L).toInt()
        } else {
            0
        }
        val weekBypassMinutes = if (usageEnabled) {
            (getShortFormBypassForegroundMillis(last7Start, now) / 60000L).toInt()
        } else {
            0
        }
        val todayLimitOverageMinutes = if (usageEnabled) {
            (getTrackedLimitOverageMillis(todayStart, now) / 60000L).toInt()
        } else {
            0
        }
        val weekLimitOverageMinutes = if (usageEnabled) {
            (getTrackedLimitOverageMillis(last7Start, now) / 60000L).toInt()
        } else {
            0
        }
        val bypassMinutesByAppId = if (usageEnabled) {
            getShortFormBypassMinutesByStatisticsAppId(last30Start, now)
        } else {
            emptyMap()
        }

        val todayAppMinutes = appDefinitions.associate { definition ->
            definition.id to trackedMinutesForAppDefinition(definition, todayUsageByPackage)
        }
        val mostUsedTodayEntry = appDefinitions
            .map { definition -> definition to (todayAppMinutes[definition.id] ?: 0) }
            .maxByOrNull { it.second }

        val websiteStats = statsEvents
            .mapNotNull { event ->
                val domain = event.metadata.optString("domain").trim().lowercase()
                if (domain.isBlank()) return@mapNotNull null
                domain to event
            }
            .groupBy({ it.first }, { it.second })
            .entries
            .map { (domain, events) ->
                mapOf(
                    "domain" to domain,
                    "blocks" to events.count { it.type == AppGuardAccessibilityService.STATS_EVENT_WEBSITE_BLOCK },
                    "bypasses" to events.count { it.type == AppGuardAccessibilityService.STATS_EVENT_WEBSITE_BYPASS },
                )
            }
            .sortedWith(
                compareByDescending<Map<String, Any>> { it["blocks"] as Int }
                    .thenByDescending { it["bypasses"] as Int }
                    .thenBy { it["domain"] as String },
            )

        val appStats = appDefinitions.map { definition ->
            val daySeries = appDailyMinutes[definition.id].orEmpty()
            val appEvents = statsEvents.filter { event ->
                definition.matches(event.packageName)
            }
            val todayMinutes = todayAppMinutes[definition.id] ?: 0
            val weekMinutes = daySeries.takeLast(7).sum()
            val launchCountToday = appDailySessionCounts[definition.id]?.lastOrNull() ?: 0
            val launchCountWeek = appDailySessionCounts[definition.id].orEmpty().takeLast(7).sum()
            val longestSessionMinutes30d =
                appDailyLongestSessionMinutes[definition.id].orEmpty().maxOrNull() ?: 0

            mapOf(
                "id" to definition.id,
                "appName" to definition.appName,
                "packageName" to definition.packageName,
                "todayMinutes" to todayMinutes,
                "weekMinutes" to weekMinutes,
                "averageDailyMinutes7d" to (weekMinutes / 7.0),
                "highestDayMinutes30d" to (daySeries.maxOrNull() ?: 0),
                "launchCountToday" to launchCountToday,
                "launchCountWeek" to launchCountWeek,
                "longestSessionMinutes30d" to longestSessionMinutes30d,
                "reelsBlocks" to appEvents.count { it.type == AppGuardAccessibilityService.STATS_EVENT_REELS_BLOCK },
                "shortsBlocks" to appEvents.count { it.type == AppGuardAccessibilityService.STATS_EVENT_SHORTS_BLOCK },
                "spotlightBlocks" to appEvents.count { it.type == AppGuardAccessibilityService.STATS_EVENT_SPOTLIGHT_BLOCK },
                "pauseOnOpenPrompts" to appEvents.count { it.type == AppGuardAccessibilityService.STATS_EVENT_PAUSE_ON_OPEN_PROMPT },
                "dailyLimitHits" to appEvents.count { it.type == AppGuardAccessibilityService.STATS_EVENT_DAILY_LIMIT_HIT },
                "bypasses" to appEvents.count { event ->
                    event.type == AppGuardAccessibilityService.STATS_EVENT_SHORT_FORM_BYPASS ||
                        event.type == AppGuardAccessibilityService.STATS_EVENT_PAUSE_ON_OPEN_BYPASS ||
                        event.type == AppGuardAccessibilityService.STATS_EVENT_DAILY_LIMIT_BYPASS
                },
                "bypassedMinutes" to (bypassMinutesByAppId[definition.id] ?: 0),
                "dailyMinutes30d" to daySeries,
            )
        }.sortedByDescending { app -> app["weekMinutes"] as Int }

        val streaks = getStreakStatistics()
        val eventTypeCounts = summarizeEventsByType(statsEvents)

        return mapOf(
            "generatedAtMillis" to now,
            "overview" to mapOf(
                "todayTrackedMinutes" to todayTrackedMinutes,
                "weekTrackedMinutes" to weekTrackedMinutes,
                "averageDailyTrackedMinutes7d" to averageDailyTrackedMinutes,
                "todayBlocks" to countBlockEvents(todayEvents),
                "todayBypasses" to countBypassEvents(todayEvents),
                "todayBypassMinutes" to todayBypassMinutes,
                "weekBypassMinutes" to weekBypassMinutes,
                "todayLimitOverageMinutes" to todayLimitOverageMinutes,
                "weekLimitOverageMinutes" to weekLimitOverageMinutes,
                "currentStreak" to streaks.first,
                "longestStreak" to streaks.second,
                "mostUsedAppName" to (mostUsedTodayEntry?.first?.appName ?: ""),
                "mostUsedAppMinutes" to (mostUsedTodayEntry?.second ?: 0),
                "blockedWebsitesCount" to getBlockedWebsites().size,
            ),
            "daily" to dailySummaries,
            "protection" to mapOf(
                "reelsBlocks" to eventTypeCounts.getValue(AppGuardAccessibilityService.STATS_EVENT_REELS_BLOCK),
                "shortsBlocks" to eventTypeCounts.getValue(AppGuardAccessibilityService.STATS_EVENT_SHORTS_BLOCK),
                "spotlightBlocks" to eventTypeCounts.getValue(AppGuardAccessibilityService.STATS_EVENT_SPOTLIGHT_BLOCK),
                "websiteBlocks" to eventTypeCounts.getValue(AppGuardAccessibilityService.STATS_EVENT_WEBSITE_BLOCK),
                "pauseOnOpenPrompts" to eventTypeCounts.getValue(AppGuardAccessibilityService.STATS_EVENT_PAUSE_ON_OPEN_PROMPT),
                "dailyLimitHits" to eventTypeCounts.getValue(AppGuardAccessibilityService.STATS_EVENT_DAILY_LIMIT_HIT),
                "totalBlocks" to countBlockEvents(statsEvents),
                "shortFormBypasses" to eventTypeCounts.getValue(AppGuardAccessibilityService.STATS_EVENT_SHORT_FORM_BYPASS),
                "websiteBypasses" to eventTypeCounts.getValue(AppGuardAccessibilityService.STATS_EVENT_WEBSITE_BYPASS),
                "pauseOnOpenBypasses" to eventTypeCounts.getValue(AppGuardAccessibilityService.STATS_EVENT_PAUSE_ON_OPEN_BYPASS),
                "dailyLimitBypasses" to eventTypeCounts.getValue(AppGuardAccessibilityService.STATS_EVENT_DAILY_LIMIT_BYPASS),
                "totalBypasses" to countBypassEvents(statsEvents),
            ),
            "timeOfDay" to buildTimeOfDayBuckets(statsEvents),
            "apps" to appStats,
            "websites" to websiteStats,
        )
    }

    private fun getInstalledTrackedPackages(): List<String> {
        val launcherIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val launcherPackages = packageManager
            .queryIntentActivities(launcherIntent, 0)
            .mapNotNull { resolveInfo -> resolveInfo.activityInfo?.packageName }

        return launcherPackages.filter { packageName -> isTrackedUsagePackage(packageName) }
    }

    private fun getInstalledTrackedApps(): List<Map<String, Any>> {
        val launcherIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return packageManager
            .queryIntentActivities(launcherIntent, 0)
            .mapNotNull { resolveInfo ->
                val activityInfo = resolveInfo.activityInfo ?: return@mapNotNull null
                val appPackageName = activityInfo.packageName ?: return@mapNotNull null
                if (appPackageName == packageName || !isTrackedUsagePackage(appPackageName)) {
                    return@mapNotNull null
                }
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

    private fun getAllForegroundMillisByPackage(
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
                        val previousPackage = currentForegroundPackage!!
                        val duration = event.timeStamp - currentForegroundStart
                        if (duration > 0L) {
                            totalsByPackage[previousPackage] =
                                (totalsByPackage[previousPackage] ?: 0L) + duration
                        }
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
                        val duration = event.timeStamp - currentForegroundStart
                        totalsByPackage[packageName] =
                            (totalsByPackage[packageName] ?: 0L) + duration
                        currentForegroundPackage = null
                        currentForegroundStart = 0L
                    }
                }
            }
        }

        if (currentForegroundPackage != null && endTime > currentForegroundStart) {
            val packageName = currentForegroundPackage!!
            val duration = endTime - currentForegroundStart
            if (duration > 0L) {
                totalsByPackage[packageName] =
                    (totalsByPackage[packageName] ?: 0L) + duration
            }
        }

        return totalsByPackage
    }

    private fun getForegroundUsageSummary(
        startTime: Long,
        endTime: Long,
    ): ForegroundUsageSummary {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val usageEvents = usageStatsManager.queryEvents(startTime, endTime)
        val event = UsageEvents.Event()
        var currentForegroundPackage: String? = null
        var currentForegroundStart = 0L
        val totalsByPackage = mutableMapOf<String, Long>()
        val hourlyTrackedMinutes = MutableList(24) { 0 }
        val hourlyTrackedMinutesByPackage = mutableMapOf<String, MutableList<Int>>()

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
                        addUsageSummaryDuration(
                            packageName = currentForegroundPackage!!,
                            startTime = currentForegroundStart,
                            endTime = event.timeStamp,
                            totalsByPackage = totalsByPackage,
                            hourlyTrackedMinutes = hourlyTrackedMinutes,
                            hourlyTrackedMinutesByPackage = hourlyTrackedMinutesByPackage,
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
                        addUsageSummaryDuration(
                            packageName = packageName,
                            startTime = currentForegroundStart,
                            endTime = event.timeStamp,
                            totalsByPackage = totalsByPackage,
                            hourlyTrackedMinutes = hourlyTrackedMinutes,
                            hourlyTrackedMinutesByPackage = hourlyTrackedMinutesByPackage,
                        )
                        currentForegroundPackage = null
                        currentForegroundStart = 0L
                    }
                }
            }
        }

        if (currentForegroundPackage != null && endTime > currentForegroundStart) {
            addUsageSummaryDuration(
                packageName = currentForegroundPackage!!,
                startTime = currentForegroundStart,
                endTime = endTime,
                totalsByPackage = totalsByPackage,
                hourlyTrackedMinutes = hourlyTrackedMinutes,
                hourlyTrackedMinutesByPackage = hourlyTrackedMinutesByPackage,
            )
        }

        return ForegroundUsageSummary(
            totalsByPackage = totalsByPackage,
            hourlyTrackedMinutes = hourlyTrackedMinutes,
            hourlyTrackedMinutesByPackage = hourlyTrackedMinutesByPackage,
        )
    }

    private fun addUsageSummaryDuration(
        packageName: String,
        startTime: Long,
        endTime: Long,
        totalsByPackage: MutableMap<String, Long>,
        hourlyTrackedMinutes: MutableList<Int>,
        hourlyTrackedMinutesByPackage: MutableMap<String, MutableList<Int>>,
    ) {
        val duration = endTime - startTime
        if (duration <= 0L) return

        totalsByPackage[packageName] = (totalsByPackage[packageName] ?: 0L) + duration
        val packageHourlyMinutes = hourlyTrackedMinutesByPackage.getOrPut(packageName) {
            MutableList(24) { 0 }
        }

        var current = startTime
        while (current < endTime) {
            val calendar = Calendar.getInstance().apply {
                timeInMillis = current
            }
            val hour = calendar.get(Calendar.HOUR_OF_DAY)
            calendar.add(Calendar.HOUR_OF_DAY, 1)
            calendar.set(Calendar.MINUTE, 0)
            calendar.set(Calendar.SECOND, 0)
            calendar.set(Calendar.MILLISECOND, 0)
            val nextHourStart = calendar.timeInMillis
            val segmentEnd = minOf(endTime, nextHourStart)
            val minutes = ((segmentEnd - current) / 60000L).toInt()
            if (minutes > 0) {
                hourlyTrackedMinutes[hour] = hourlyTrackedMinutes[hour] + minutes
                packageHourlyMinutes[hour] = packageHourlyMinutes[hour] + minutes
            }
            current = segmentEnd
        }
    }

    private fun hourlyTrackedMinutesForAppDefinition(
        definition: StatisticsAppDefinition,
        hourlyTrackedMinutesByPackage: Map<String, List<Int>>,
    ): List<Int> {
        val totals = MutableList(24) { 0 }
        for ((packageName, hourlyMinutes) in hourlyTrackedMinutesByPackage) {
            if (!definition.matches(packageName)) continue
            for (hour in 0 until minOf(24, hourlyMinutes.size)) {
                totals[hour] = totals[hour] + hourlyMinutes[hour]
            }
        }
        return totals
    }

    private fun getForegroundMillisForAppLimit(
        appLimit: AppLimit,
        startTime: Long,
        endTime: Long,
    ): Long {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val usageEvents = usageStatsManager.queryEvents(startTime, endTime)
        val event = UsageEvents.Event()
        val activeStartTimes = mutableMapOf<String, Long>()
        var totalMillis = 0L

        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            val packageName = event.packageName ?: continue
            if (!appLimit.matches(packageName)) continue

            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED,
                UsageEvents.Event.MOVE_TO_FOREGROUND,
                -> {
                    activeStartTimes[packageName] = event.timeStamp
                }

                UsageEvents.Event.ACTIVITY_PAUSED,
                UsageEvents.Event.MOVE_TO_BACKGROUND,
                -> {
                    val start = activeStartTimes.remove(packageName) ?: continue
                    if (event.timeStamp > start) {
                        totalMillis += event.timeStamp - start
                    }
                }
            }
        }

        activeStartTimes.values.forEach { start ->
            if (endTime > start) {
                totalMillis += endTime - start
            }
        }

        return totalMillis
    }

    private fun getTrackedLimitOverageMillis(
        startTime: Long,
        endTime: Long,
    ): Long {
        val prefs = getSharedPreferences(AppGuardAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
        var totalOverageMillis = 0L

        for (appLimit in getTrackedAppLimits()) {
            if (!prefs.contains(appLimit.settingKey)) continue
            val configuredMinutes = prefs.getInt(appLimit.settingKey, 0)
            val limitMillis = when {
                configuredMinutes == AppGuardAccessibilityService.TEN_SECOND_LIMIT_VALUE -> 10000L
                configuredMinutes > 0 -> configuredMinutes * 60000L
                else -> 0L
            }
            if (limitMillis <= 0L) continue

            val foregroundMillis = getForegroundMillisForAppLimit(
                appLimit = appLimit,
                startTime = startTime,
                endTime = endTime,
            )
            totalOverageMillis += (foregroundMillis - limitMillis).coerceAtLeast(0L)
        }

        return totalOverageMillis
    }

    private fun getShortFormBypassForegroundMillis(
        startTime: Long,
        endTime: Long,
    ): Long {
        val windows = getShortFormBypassWindows()
            .filter { window ->
                window.endMillis > startTime && window.startMillis < endTime
            }
        if (windows.isEmpty()) return 0L

        return windows
            .groupBy { it.target }
            .entries
            .sumOf { (target, targetWindows) ->
                val appLimit = when (target) {
                    AppGuardAccessibilityService.TARGET_YOUTUBE -> builtInTrackedAppLimits.first {
                        it.settingKey == "youtube_app"
                    }
                    else -> builtInTrackedAppLimits.first {
                        it.settingKey == "instagram_app"
                    }
                }

                mergeBypassWindows(targetWindows, startTime, endTime).sumOf { window ->
                    getForegroundMillisForAppLimit(
                        appLimit = appLimit,
                        startTime = window.startMillis,
                        endTime = window.endMillis,
                    )
                }
            }
    }

    private fun getShortFormBypassMinutesByStatisticsAppId(
        startTime: Long,
        endTime: Long,
    ): Map<String, Int> {
        val windows = getShortFormBypassWindows()
            .filter { window ->
                window.endMillis > startTime && window.startMillis < endTime
            }
        if (windows.isEmpty()) return emptyMap()

        val totalsByAppId = mutableMapOf<String, Int>()
        val definitionsByTarget = mapOf(
            AppGuardAccessibilityService.TARGET_INSTAGRAM to getStatisticsAppDefinitions().firstOrNull {
                it.id == "instagram"
            },
            AppGuardAccessibilityService.TARGET_YOUTUBE to getStatisticsAppDefinitions().firstOrNull {
                it.id == "youtube"
            },
        )

        for ((target, definition) in definitionsByTarget) {
            if (definition == null) continue
            val targetWindows = windows.filter { it.target == target }
            if (targetWindows.isEmpty()) continue

            val mergedWindows = mergeBypassWindows(targetWindows, startTime, endTime)
            val totalMinutes = mergedWindows.sumOf { window ->
                (getForegroundMillisForAppDefinition(
                    definition = definition,
                    startTime = window.startMillis,
                    endTime = window.endMillis,
                ) / 60000L).toInt()
            }
            totalsByAppId[definition.id] = totalMinutes
        }

        return totalsByAppId
    }

    private fun mergeBypassWindows(
        windows: List<ShortFormBypassWindow>,
        startTime: Long,
        endTime: Long,
    ): List<ShortFormBypassWindow> {
        if (windows.isEmpty()) return emptyList()

        val sortedWindows = windows
            .map { window ->
                window.copy(
                    startMillis = maxOf(window.startMillis, startTime),
                    endMillis = minOf(window.endMillis, endTime),
                )
            }
            .filter { window -> window.endMillis > window.startMillis }
            .sortedBy { window -> window.startMillis }
        if (sortedWindows.isEmpty()) return emptyList()

        val merged = mutableListOf(sortedWindows.first())
        for (index in 1 until sortedWindows.size) {
            val currentWindow = sortedWindows[index]
            val lastWindow = merged.removeAt(merged.lastIndex)
            if (currentWindow.startMillis <= lastWindow.endMillis) {
                merged.add(
                    lastWindow.copy(
                        endMillis = maxOf(lastWindow.endMillis, currentWindow.endMillis),
                    ),
                )
            } else {
                merged.add(lastWindow)
                merged.add(currentWindow)
            }
        }
        return merged
    }

    private fun getShortFormBypassWindows(): List<ShortFormBypassWindow> {
        val prefs = getSharedPreferences(AppGuardAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
        val serialized = prefs.getString(
            AppGuardAccessibilityService.SHORT_FORM_BYPASS_WINDOWS_PREF_KEY,
            null,
        ) ?: return emptyList()
        val jsonArray = JSONArray(serialized)

        return List(jsonArray.length()) { index ->
            val entry = jsonArray.optJSONObject(index) ?: JSONObject()
            ShortFormBypassWindow(
                target = entry.optString("target"),
                startMillis = entry.optLong("startMillis"),
                endMillis = entry.optLong("endMillis"),
            )
        }.filter { window ->
            window.target.isNotBlank() && window.endMillis > window.startMillis
        }
    }

    private fun getStatsEvents(): List<StatsEvent> {
        val prefs = getSharedPreferences(AppGuardAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
        val serialized = prefs.getString(AppGuardAccessibilityService.STATS_EVENT_LOG_PREF_KEY, null)
            ?: return emptyList()
        val jsonArray = JSONArray(serialized)
        val events = List(jsonArray.length()) { index ->
            val entry = jsonArray.optJSONObject(index) ?: JSONObject()
            StatsEvent(
                timestamp = entry.optLong("timestamp"),
                type = entry.optString("type"),
                packageName = entry.optString("packageName"),
                target = entry.optString("target"),
                metadata = entry.optJSONObject("metadata") ?: JSONObject(),
            )
        }.filter { event ->
            event.timestamp > 0L && event.type.isNotBlank()
        }
        return deduplicateStatsEvents(events)
    }

    private fun deduplicateStatsEvents(events: List<StatsEvent>): List<StatsEvent> {
        if (events.isEmpty()) return events

        val sortedEvents = events.sortedBy { event -> event.timestamp }
        val deduplicatedEvents = mutableListOf<StatsEvent>()
        val lastBlockTimestampByKey = mutableMapOf<String, Long>()

        for (event in sortedEvents) {
            if (!isBlockEventType(event.type)) {
                deduplicatedEvents.add(event)
                continue
            }

            val key = buildBlockEventDeduplicationKey(event)
            val lastTimestamp = lastBlockTimestampByKey[key]
            if (
                lastTimestamp != null &&
                    event.timestamp - lastTimestamp <= BLOCK_EVENT_DEDUPLICATION_WINDOW_MILLIS
            ) {
                continue
            }

            lastBlockTimestampByKey[key] = event.timestamp
            deduplicatedEvents.add(event)
        }

        return deduplicatedEvents
    }

    private fun buildBlockEventDeduplicationKey(event: StatsEvent): String {
        val domain = event.metadata.optString("domain").trim().lowercase()
        return listOf(
            event.type,
            event.packageName,
            event.target,
            domain,
        ).joinToString(separator = "|")
    }

    private fun summarizeEventsByType(events: List<StatsEvent>): Map<String, Int> {
        val counts = mutableMapOf(
            AppGuardAccessibilityService.STATS_EVENT_REELS_BLOCK to 0,
            AppGuardAccessibilityService.STATS_EVENT_SHORTS_BLOCK to 0,
            AppGuardAccessibilityService.STATS_EVENT_SPOTLIGHT_BLOCK to 0,
            AppGuardAccessibilityService.STATS_EVENT_WEBSITE_BLOCK to 0,
            AppGuardAccessibilityService.STATS_EVENT_PAUSE_ON_OPEN_PROMPT to 0,
            AppGuardAccessibilityService.STATS_EVENT_DAILY_LIMIT_HIT to 0,
            AppGuardAccessibilityService.STATS_EVENT_SHORT_FORM_BYPASS to 0,
            AppGuardAccessibilityService.STATS_EVENT_WEBSITE_BYPASS to 0,
            AppGuardAccessibilityService.STATS_EVENT_PAUSE_ON_OPEN_BYPASS to 0,
            AppGuardAccessibilityService.STATS_EVENT_DAILY_LIMIT_BYPASS to 0,
        )
        for (event in events) {
            counts[event.type] = (counts[event.type] ?: 0) + 1
        }
        return counts
    }

    private fun countBlockEvents(events: List<StatsEvent>): Int {
        return events.count { event ->
            event.type == AppGuardAccessibilityService.STATS_EVENT_REELS_BLOCK ||
                event.type == AppGuardAccessibilityService.STATS_EVENT_SHORTS_BLOCK ||
                event.type == AppGuardAccessibilityService.STATS_EVENT_SPOTLIGHT_BLOCK ||
                event.type == AppGuardAccessibilityService.STATS_EVENT_WEBSITE_BLOCK
        }
    }

    private fun countBypassEvents(events: List<StatsEvent>): Int {
        return events.count { event ->
            event.type == AppGuardAccessibilityService.STATS_EVENT_SHORT_FORM_BYPASS ||
                event.type == AppGuardAccessibilityService.STATS_EVENT_WEBSITE_BYPASS ||
                event.type == AppGuardAccessibilityService.STATS_EVENT_PAUSE_ON_OPEN_BYPASS ||
                event.type == AppGuardAccessibilityService.STATS_EVENT_DAILY_LIMIT_BYPASS
        }
    }

    private fun isBlockEventType(eventType: String): Boolean {
        return eventType == AppGuardAccessibilityService.STATS_EVENT_REELS_BLOCK ||
            eventType == AppGuardAccessibilityService.STATS_EVENT_SHORTS_BLOCK ||
            eventType == AppGuardAccessibilityService.STATS_EVENT_SPOTLIGHT_BLOCK ||
            eventType == AppGuardAccessibilityService.STATS_EVENT_WEBSITE_BLOCK
    }

    private fun isBypassEventType(eventType: String): Boolean {
        return eventType == AppGuardAccessibilityService.STATS_EVENT_SHORT_FORM_BYPASS ||
            eventType == AppGuardAccessibilityService.STATS_EVENT_WEBSITE_BYPASS ||
            eventType == AppGuardAccessibilityService.STATS_EVENT_PAUSE_ON_OPEN_BYPASS ||
            eventType == AppGuardAccessibilityService.STATS_EVENT_DAILY_LIMIT_BYPASS
    }

    private fun emptyTimeOfDayCounts(): Map<String, Int> {
        return linkedMapOf(
            "Morning" to 0,
            "Afternoon" to 0,
            "Evening" to 0,
            "Late Night" to 0,
        )
    }

    private fun timeOfDayBucketLabel(timestamp: Long): String {
        val hour = Calendar.getInstance().apply {
            timeInMillis = timestamp
        }.get(Calendar.HOUR_OF_DAY)
        return when {
            hour in 5 until 12 -> "Morning"
            hour in 12 until 17 -> "Afternoon"
            hour in 17 until 22 -> "Evening"
            else -> "Late Night"
        }
    }

    private fun buildTimeOfDayBuckets(events: List<StatsEvent>): List<Map<String, Any>> {
        val buckets = listOf(
            Triple("Morning", 5, 12),
            Triple("Afternoon", 12, 17),
            Triple("Evening", 17, 22),
            Triple("Late Night", 22, 29),
        )
        return buckets.map { (label, startHour, endHour) ->
            val bucketEvents = events.filter { event ->
                val hour = Calendar.getInstance().apply {
                    timeInMillis = event.timestamp
                }.get(Calendar.HOUR_OF_DAY)
                if (endHour > 24) {
                    hour >= startHour || hour < (endHour - 24)
                } else {
                    hour in startHour until endHour
                }
            }
            mapOf(
                "label" to label,
                "blocks" to countBlockEvents(bucketEvents),
                "bypasses" to countBypassEvents(bucketEvents),
            )
        }
    }

    private fun getStatisticsAppDefinitions(): List<StatisticsAppDefinition> {
        val groupedApps = linkedMapOf<String, MutableList<Map<String, Any>>>()
        for (app in getInstalledApps()) {
            val packageName = app["packageName"] as? String ?: continue
            val appName = app["appName"] as? String ?: packageName
            val id = statisticsAppIdForPackage(packageName)
            groupedApps.getOrPut(id) { mutableListOf() }.add(
                mapOf(
                    "packageName" to packageName,
                    "appName" to appName,
                ),
            )
        }

        return groupedApps.entries.map { (id, apps) ->
            val packageNames = apps.mapNotNull { it["packageName"] as? String }.toSet()
            val preferredPackageName = when {
                id == "youtube" && packageNames.contains("com.google.android.youtube") ->
                    "com.google.android.youtube"
                id == "instagram" && packageNames.contains("com.instagram.android") ->
                    "com.instagram.android"
                id == "snapchat" && packageNames.contains("com.snapchat.android") ->
                    "com.snapchat.android"
                else -> packageNames.firstOrNull().orEmpty()
            }
            val appName = when (id) {
                "instagram" -> "Instagram"
                "snapchat" -> "Snapchat"
                "youtube" -> "YouTube"
                else -> (apps.firstOrNull()?.get("appName") as? String).orEmpty()
            }
            StatisticsAppDefinition(
                id = id,
                appName = appName.ifBlank { preferredPackageName },
                packageName = preferredPackageName,
                matcher = { candidate -> packageNames.contains(candidate) },
            )
        }
    }

    private fun statisticsAppIdForPackage(packageName: String): String {
        val packageLower = packageName.lowercase()
        if (
            packageLower == "com.google.android.youtube" ||
            packageLower.startsWith("app.revanced.android.youtube")
        ) {
            return "youtube"
        }
        if (packageLower == "com.instagram.android") {
            return "instagram"
        }
        if (packageLower == "com.snapchat.android") {
            return "snapchat"
        }
        return packageName
    }

    private fun trackedMinutesForAppDefinition(
        definition: StatisticsAppDefinition,
        usageByPackage: Map<String, Long>,
    ): Int {
        return usageByPackage.entries.sumOf { entry ->
            if (definition.matches(entry.key)) {
                (entry.value / 60000L).toInt()
            } else {
                0
            }
        }
    }

    private fun getForegroundMillisForAppDefinition(
        definition: StatisticsAppDefinition,
        startTime: Long,
        endTime: Long,
    ): Long {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val usageEvents = usageStatsManager.queryEvents(startTime, endTime)
        val event = UsageEvents.Event()
        val activeStartTimes = mutableMapOf<String, Long>()
        var totalMillis = 0L

        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            val packageName = event.packageName ?: continue
            if (shouldIgnoreUsagePackage(packageName)) continue
            if (!definition.matches(packageName)) continue

            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED,
                UsageEvents.Event.MOVE_TO_FOREGROUND,
                -> {
                    activeStartTimes[packageName] = event.timeStamp
                }

                UsageEvents.Event.ACTIVITY_PAUSED,
                UsageEvents.Event.MOVE_TO_BACKGROUND,
                -> {
                    val start = activeStartTimes.remove(packageName) ?: continue
                    if (event.timeStamp > start) {
                        totalMillis += event.timeStamp - start
                    }
                }
            }
        }

        activeStartTimes.values.forEach { start ->
            if (endTime > start) {
                totalMillis += endTime - start
            }
        }

        return totalMillis
    }

    private fun getForegroundEntryCountForAppDefinition(
        definition: StatisticsAppDefinition,
        startTime: Long,
        endTime: Long,
    ): Int {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val usageEvents = usageStatsManager.queryEvents(startTime, endTime)
        val event = UsageEvents.Event()
        var count = 0

        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            val packageName = event.packageName ?: continue
            if (!definition.matches(packageName)) continue
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                count++
            }
        }

        return count
    }

    private fun getForegroundSessionStatsForDefinitions(
        definitions: List<StatisticsAppDefinition>,
        startTime: Long,
        endTime: Long,
    ): SessionStats {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val usageEvents = usageStatsManager.queryEvents(startTime, endTime)
        val event = UsageEvents.Event()
        val activeStartTimesByPackage = mutableMapOf<String, Long>()
        val activeAppIdByPackage = mutableMapOf<String, String>()
        val countsByAppId = mutableMapOf<String, Int>()
        val longestSessionMinutesByAppId = mutableMapOf<String, Int>()

        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            val packageName = event.packageName ?: continue
            val definition = definitions.firstOrNull { it.matches(packageName) } ?: continue

            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED,
                UsageEvents.Event.MOVE_TO_FOREGROUND,
                -> {
                    if (
                        event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND &&
                            !activeStartTimesByPackage.containsKey(packageName)
                    ) {
                        countsByAppId[definition.id] = (countsByAppId[definition.id] ?: 0) + 1
                    }
                    activeStartTimesByPackage[packageName] = event.timeStamp
                    activeAppIdByPackage[packageName] = definition.id
                }

                UsageEvents.Event.ACTIVITY_PAUSED,
                UsageEvents.Event.MOVE_TO_BACKGROUND,
                -> {
                    val start = activeStartTimesByPackage.remove(packageName) ?: continue
                    val appId = activeAppIdByPackage.remove(packageName) ?: continue
                    if (event.timeStamp <= start) continue
                    val durationMinutes = ((event.timeStamp - start) / 60000L).toInt()
                    if (durationMinutes > (longestSessionMinutesByAppId[appId] ?: 0)) {
                        longestSessionMinutesByAppId[appId] = durationMinutes
                    }
                }
            }
        }

        activeStartTimesByPackage.forEach { (packageName, start) ->
            val appId = activeAppIdByPackage[packageName] ?: return@forEach
            if (endTime <= start) return@forEach
            val durationMinutes = ((endTime - start) / 60000L).toInt()
            if (durationMinutes > (longestSessionMinutesByAppId[appId] ?: 0)) {
                longestSessionMinutesByAppId[appId] = durationMinutes
            }
        }

        return SessionStats(
            countsByAppId = countsByAppId,
            longestSessionMinutesByAppId = longestSessionMinutesByAppId,
        )
    }

    private fun getStreakStatistics(): Pair<Int, Int> {
        val firstInstallTime = packageManager.getPackageInfo(packageName, 0).firstInstallTime
        val firstTrackableDate = Calendar.getInstance().apply {
            timeInMillis = firstInstallTime
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        val todayStart = getTodayWindow().first
        val statuses = getScrollDayStatuses()

        var current = 0
        var cursor = todayStart
        while (cursor >= firstTrackableDate) {
            val status = statuses[dateKeyForMillis(cursor)] ?: 3
            if (status != 1) break
            current++
            cursor -= DAY_IN_MILLIS
        }

        var longest = 0
        var running = 0
        var day = firstTrackableDate
        while (day <= todayStart) {
            val status = statuses[dateKeyForMillis(day)] ?: 3
            if (status == 1) {
                running++
                if (running > longest) longest = running
            } else {
                running = 0
            }
            day += DAY_IN_MILLIS
        }

        return current to longest
    }

    private fun startOfDay(millis: Long): Long {
        return Calendar.getInstance().apply {
            timeInMillis = millis
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }

    private fun dateKeyForMillis(millis: Long): String {
        val calendar = Calendar.getInstance().apply {
            timeInMillis = millis
        }
        val year = calendar.get(Calendar.YEAR).toString().padStart(4, '0')
        val month = (calendar.get(Calendar.MONTH) + 1).toString().padStart(2, '0')
        val day = calendar.get(Calendar.DAY_OF_MONTH).toString().padStart(2, '0')
        return "$year-$month-$day"
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

    private fun setPauseDurationSeconds(seconds: Int) {
        val sanitizedSeconds = seconds.coerceIn(0, 15)
        getSharedPreferences(AppGuardAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putInt(AppGuardAccessibilityService.PAUSE_DURATION_SECONDS_PREF_KEY, sanitizedSeconds)
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
            "pauseDurationSeconds" to prefs.getInt(
                AppGuardAccessibilityService.PAUSE_DURATION_SECONDS_PREF_KEY,
                AppGuardAccessibilityService.DEFAULT_PAUSE_DURATION_SECONDS,
            ),
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

    private fun openWebsite(url: String) {
        startActivity(
            Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                addCategory(Intent.CATEGORY_BROWSABLE)
            },
        )
    }

    private fun shareText(text: String) {
        startActivity(
            Intent.createChooser(
                Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_TEXT, text)
                },
                null,
            ).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
        )
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
        accessibilityWatcherHandler.removeCallbacks(accessibilityEnableWatcher)
        usageAccessWatcherHandler.removeCallbacks(usageAccessEnableWatcher)
        appLoadingExecutor.shutdownNow()
        statisticsLoadingExecutor.shutdownNow()
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

    private data class ShortFormBypassWindow(
        val target: String,
        val startMillis: Long,
        val endMillis: Long,
    )

    private data class StatsEvent(
        val timestamp: Long,
        val type: String,
        val packageName: String,
        val target: String,
        val metadata: JSONObject,
    )

    private data class StatisticsAppDefinition(
        val id: String,
        val appName: String,
        val packageName: String,
        val matcher: (String) -> Boolean,
    ) {
        fun matches(candidate: String): Boolean = matcher(candidate)
    }

    private data class SessionStats(
        val countsByAppId: Map<String, Int>,
        val longestSessionMinutesByAppId: Map<String, Int>,
    )

    private val builtInTrackedAppLimits = listOf(
        AppLimit(
            settingKey = "instagram_app",
            packageNames = setOf("com.instagram.android"),
        ),
        AppLimit(
            settingKey = "snapchat_app",
            packageNames = setOf("com.snapchat.android"),
        ),
        AppLimit(
            settingKey = "youtube_app",
            packageNames = setOf("com.google.android.youtube"),
            packagePrefixes = setOf("app.revanced.android.youtube"),
        ),
    )

}
