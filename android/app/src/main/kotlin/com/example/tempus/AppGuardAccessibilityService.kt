package com.example.tempus

import android.accessibilityservice.AccessibilityService
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.util.Calendar
import org.json.JSONArray

class AppGuardAccessibilityService : AccessibilityService() {
    private var lastForegroundPackage: String? = null
    private val enforcementHandler = Handler(Looper.getMainLooper())
    private val lastVisibleBlockedWebsiteByPackage = mutableMapOf<String, String?>()
    private var promptTarget: String? = null
    private var lastInstagramReelsScanAtMillis = 0L
    private var instagramReelsDetectedUntilMillis = 0L

    override fun onServiceConnected() {
        activeService = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val eventType = event?.eventType ?: return
        if (
            eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            eventType != AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED &&
            eventType != AccessibilityEvent.TYPE_VIEW_CLICKED
        ) {
            return
        }

        val packageName = event.packageName?.toString() ?: return

        val previousPackageName = lastForegroundPackage
        if (previousPackageName != null && previousPackageName != packageName) {
            lastVisibleBlockedWebsiteByPackage.remove(previousPackageName)
        }
        if (packageName != lastForegroundPackage) {
            lastForegroundPackage = packageName
            if (packageName != INSTAGRAM_PACKAGE_NAME) {
                clearInstagramReelsDetectionCache()
            }
            if (
                promptActive &&
                promptTarget != null &&
                shouldDismissPromptForPackage(packageName, promptTarget!!)
            ) {
                dismissPromptOverlay()
            }
        }

        if (packageName == INSTAGRAM_PACKAGE_NAME && INSTAGRAM_DEBUG_LOGS_ENABLED) {
            logInstagramEvent(event, eventType)
        }
        if (isYouTubePackage(packageName) && YOUTUBE_DEBUG_LOGS_ENABLED) {
            logYouTubeEvent(event, eventType, packageName)
        }

        if (shouldBlockPackage(packageName)) {
            enforceHome(packageName)
            return
        }

        val blockedWebsiteDomain = findBlockedWebsiteDomain(packageName, event)
        if (blockedWebsiteDomain != null) {
            val previousBlockedDomain = lastVisibleBlockedWebsiteByPackage[packageName]
            lastVisibleBlockedWebsiteByPackage[packageName] = blockedWebsiteDomain
            if (!blockedWebsiteDomain.equals(previousBlockedDomain, ignoreCase = true)) {
                enforceBlockedWebsite(packageName, blockedWebsiteDomain)
                return
            }
        } else if (isSupportedBrowserPackage(packageName)) {
            lastVisibleBlockedWebsiteByPackage[packageName] = null
        }

        if (promptActive || isPackageTemporarilyAllowed(packageName)) return
        if (packageName == INSTAGRAM_PACKAGE_NAME) {
            if (!shouldOpenInstagramBlockPrompt(event, eventType)) return
            openInstagramPrompt()
            return
        }
        if (isYouTubePackage(packageName)) {
            if (!shouldOpenYouTubeBlockPrompt(event, eventType)) return
            openYouTubePrompt()
        }
    }

    override fun onInterrupt() = Unit

    override fun onDestroy() {
        if (activeService === this) {
            activeService = null
        }
        enforcementHandler.removeCallbacksAndMessages(null)
        lastVisibleBlockedWebsiteByPackage.clear()
        dismissPromptState()
        super.onDestroy()
    }

    private fun isPackageTemporarilyAllowed(packageName: String): Boolean {
        val now = System.currentTimeMillis()
        if (now < promptSuppressedUntilMillis) return true
        return when {
            packageName == INSTAGRAM_PACKAGE_NAME -> now < instagramAllowedUntilMillis
            isYouTubePackage(packageName) -> now < youTubeAllowedUntilMillis
            else -> false
        }
    }

    private fun shouldBlockPackage(packageName: String): Boolean {
        val appLimit = getTrackedAppLimits().firstOrNull { appLimit ->
            appLimit.matches(packageName)
        } ?: return false
        val limitMinutes = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getInt(appLimit.settingKey, 0)
        if (limitMinutes == 0) return false
        if (limitMinutes == TEN_SECOND_LIMIT_VALUE) {
            return getTodayForegroundMillis(appLimit) >= 10000L
        }
        if (limitMinutes < 0) return true
        return getTodayForegroundMillis(appLimit) >= limitMinutes * 60000L
    }

    private fun isInstagramReelsBlockingEnabled(): Boolean {
        return getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(INSTAGRAM_REELS_SETTING_KEY, false)
    }

    private fun isInstagramStoriesBlockingEnabled(): Boolean {
        return getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(INSTAGRAM_STORIES_SETTING_KEY, false)
    }

    private fun isYouTubeShortsBlockingEnabled(): Boolean {
        return getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(YOUTUBE_SHORTS_SETTING_KEY, false)
    }

    private fun getBlockedWebsiteDomains(): List<String> {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val serialized = prefs.getString(BLOCKED_WEBSITES_PREF_KEY, null) ?: return emptyList()
        val jsonArray = JSONArray(serialized)
        return List(jsonArray.length()) { index ->
            jsonArray.getJSONObject(index).optString("domain")
        }.map { domain ->
            normalizeDomain(domain)
        }.filter { domain ->
            domain.isNotBlank()
        }
    }

    private fun getTodayForegroundMillis(appLimit: AppLimit): Long {
        val todayWindow = getTodayWindow()
        return getForegroundMillisForAppLimit(
            appLimit = appLimit,
            startTime = todayWindow.first,
            endTime = todayWindow.second,
        )
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

    private fun goHome() {
        startActivity(
            Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            },
        )
    }

    private fun enforceHome(packageName: String) {
        goHome()
        repeat(BLOCK_RETRY_COUNT) { retryIndex ->
            enforcementHandler.postDelayed(
                {
                    if (lastForegroundPackage == packageName && shouldBlockPackage(packageName)) {
                        goHome()
                    }
                },
                (retryIndex + 1) * BLOCK_RETRY_DELAY_MS,
            )
        }
    }

    private fun enforceBlockedWebsite(packageName: String, blockedDomain: String) {
        goHome()
        repeat(BLOCK_RETRY_COUNT) { retryIndex ->
            enforcementHandler.postDelayed(
                {
                    if (
                        lastForegroundPackage == packageName &&
                        isBlockedWebsiteVisibleForPackage(packageName, blockedDomain)
                    ) {
                        goHome()
                    }
                },
                (retryIndex + 1) * BLOCK_RETRY_DELAY_MS,
            )
        }
    }

    private fun openInstagramPrompt() {
        promptActive = true
        showPromptActivity(TARGET_INSTAGRAM)
    }

    private fun openYouTubePrompt() {
        promptActive = true
        showPromptActivity(TARGET_YOUTUBE)
    }

    private fun showPromptActivity(target: String) {
        enforcementHandler.post {
            dismissPromptState()
            promptTarget = target
            val intent = Intent(this, ConfirmBlockerActivity::class.java).apply {
                putExtra(ConfirmBlockerActivity.EXTRA_TARGET, target)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            runCatching {
                startActivity(intent)
                Log.d(PROMPT_DEBUG_TAG, "Showing blocker activity for target=$target")
            }.onFailure {
                Log.e(PROMPT_DEBUG_TAG, "Failed to show blocker activity", it)
                dismissPromptState()
            }
        }
    }

    private fun dismissPromptState() {
        promptTarget = null
        promptActive = false
    }

    private fun dismissPromptOverlay() {
        enforcementHandler.post {
            dismissPromptState()
        }
    }

    private fun doesPackageMatchPromptTarget(packageName: String, target: String): Boolean {
        return when (target) {
            TARGET_YOUTUBE -> isYouTubePackage(packageName)
            else -> packageName == INSTAGRAM_PACKAGE_NAME
        }
    }

    private fun shouldDismissPromptForPackage(packageName: String, target: String): Boolean {
        if (packageName == this.packageName) return false
        if (packageName == "android") return false
        if (packageName == "com.android.systemui") return false
        return !doesPackageMatchPromptTarget(packageName, target)
    }

    private fun shouldOpenInstagramBlockPrompt(
        event: AccessibilityEvent,
        eventType: Int,
    ): Boolean {
        if (isInstagramReelsBlockingEnabled()) {
            if (
                (eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED ||
                    eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) &&
                isInstagramReelsScreen()
            ) {
                return true
            }
        }
        if (isInstagramStoriesBlockingEnabled()) {
            if (
                eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED &&
                isStoriesContentScreen()
            ) {
                return true
            }
        }
        return false
    }

    private fun shouldOpenYouTubeBlockPrompt(
        event: AccessibilityEvent,
        eventType: Int,
    ): Boolean {
        if (
            eventType == AccessibilityEvent.TYPE_VIEW_CLICKED &&
            isYouTubeShortsBlockingEnabled()
        ) {
            return isYouTubeShortsClick(event)
        }
        return false
    }

    private fun isInstagramReelsScreen(): Boolean {
        val now = System.currentTimeMillis()
        if (now < instagramReelsDetectedUntilMillis) {
            return true
        }
        if (now - lastInstagramReelsScanAtMillis < INSTAGRAM_REELS_SCAN_DEBOUNCE_MILLIS) {
            return false
        }
        lastInstagramReelsScanAtMillis = now

        val rootNode = rootInActiveWindow ?: return false
        val reelsNodes = rootNode.findAccessibilityNodeInfosByViewId(INSTAGRAM_REELS_CONTAINER_VIEW_ID)
            ?: return false

        val isDetected = reelsNodes.any { node ->
            node?.isVisibleToUser == true &&
                !node.isContentInvalid &&
                node.viewIdResourceName == INSTAGRAM_REELS_CONTAINER_VIEW_ID
        }

        if (isDetected) {
            instagramReelsDetectedUntilMillis = now + INSTAGRAM_REELS_DETECTION_CACHE_MILLIS
        }

        return isDetected
    }

    private fun clearInstagramReelsDetectionCache() {
        lastInstagramReelsScanAtMillis = 0L
        instagramReelsDetectedUntilMillis = 0L
    }

    private fun isStoriesContentScreen(): Boolean {
        val rootNode = rootInActiveWindow ?: return false
        val rootText = buildNodeText(rootNode)
            .replace(Regex("\\s+"), " ")
            .trim()
        return rootText.startsWith("Send message or reaction", ignoreCase = true)
    }

    private fun isYouTubeShortsClick(event: AccessibilityEvent): Boolean {
        val clickedLabel = buildString {
            event.text.forEach { append(' ').append(it) }
            append(' ').append(event.contentDescription?.toString().orEmpty())
        }.trim()
        return clickedLabel.equals("More actions", ignoreCase = true) ||
            clickedLabel.equals("Shorts Shorts", ignoreCase = true)
    }

    private fun findBlockedWebsiteDomain(
        packageName: String,
        event: AccessibilityEvent,
    ): String? {
        if (!isSupportedBrowserPackage(packageName)) return null
        val blockedDomains = getBlockedWebsiteDomains()
        if (blockedDomains.isEmpty()) return null
        val visibleText = buildVisibleBrowserText(event)
        return blockedDomains.firstOrNull { domain ->
            containsBlockedDomain(visibleText, domain)
        }
    }

    private fun isBlockedWebsiteVisibleForPackage(
        packageName: String,
        blockedDomain: String,
    ): Boolean {
        if (!isSupportedBrowserPackage(packageName)) return false
        val rootNode = rootInActiveWindow ?: return false
        val visibleText = buildNodeText(rootNode)
        return containsBlockedDomain(visibleText, blockedDomain)
    }

    private fun buildVisibleBrowserText(event: AccessibilityEvent): String {
        val eventText = buildString {
            event.text.forEach { append(' ').append(it) }
            append(' ').append(event.contentDescription?.toString().orEmpty())
        }
        val rootText = rootInActiveWindow?.let(::buildNodeText).orEmpty()
        return "$eventText $rootText".replace(Regex("\\s+"), " ").trim()
    }

    private fun containsBlockedDomain(visibleText: String, blockedDomain: String): Boolean {
        if (visibleText.isBlank() || blockedDomain.isBlank()) return false
        val normalizedText = visibleText.lowercase()
        val normalizedDomain = normalizeDomain(blockedDomain)
        if (normalizedDomain.isBlank()) return false
        return normalizedText.contains(normalizedDomain)
    }

    private fun normalizeDomain(domain: String): String {
        return domain
            .trim()
            .lowercase()
            .removePrefix("https://")
            .removePrefix("http://")
            .removePrefix("www.")
            .trimEnd('/')
    }

    private fun logInstagramEvent(event: AccessibilityEvent, eventType: Int) {
        logDebugEvent(INSTAGRAM_DEBUG_TAG, event, eventType)
    }

    private fun logYouTubeEvent(
        event: AccessibilityEvent,
        eventType: Int,
        packageName: String,
    ) {
        logDebugEvent(
            YOUTUBE_DEBUG_TAG,
            event,
            eventType,
            prefix = "package=\"$packageName\" ",
        )
    }

    private fun logDebugEvent(
        tag: String,
        event: AccessibilityEvent,
        eventType: Int,
        prefix: String = "",
    ) {
        val clickLabel = buildString {
            event.text.forEach { append(' ').append(it) }
            append(' ').append(event.contentDescription?.toString().orEmpty())
        }.trim().ifBlank { "-" }
        val rootSummary = rootInActiveWindow?.let(::buildNodeText)
            ?.replace(Regex("\\s+"), " ")
            ?.trim()
            ?.ifBlank { "-" }
            ?: "-"
        Log.d(
            tag,
            "${prefix}event=${eventTypeName(eventType)} clickLabel=\"$clickLabel\" root=\"$rootSummary\"",
        )
    }

    private fun buildNodeText(node: AccessibilityNodeInfo): String {
        val collectedText = StringBuilder()
        collectNodeText(node, collectedText)
        return collectedText.toString()
    }

    private fun collectNodeText(node: AccessibilityNodeInfo?, collector: StringBuilder) {
        if (node == null) return
        val text = node.text?.toString()
        if (!text.isNullOrBlank()) {
            collector.append(' ').append(text)
        }
        val description = node.contentDescription?.toString()
        if (!description.isNullOrBlank()) {
            collector.append(' ').append(description)
        }
        for (index in 0 until node.childCount) {
            collectNodeText(node.getChild(index), collector)
        }
    }

    private fun eventTypeName(eventType: Int): String {
        return when (eventType) {
            AccessibilityEvent.TYPE_VIEW_CLICKED -> "TYPE_VIEW_CLICKED"
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> "TYPE_WINDOW_STATE_CHANGED"
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> "TYPE_WINDOW_CONTENT_CHANGED"
            else -> eventType.toString()
        }
    }

    private fun isYouTubePackage(packageName: String): Boolean {
        return packageName == YOUTUBE_PACKAGE_NAME ||
            packageName.startsWith(YOUTUBE_REVANCED_PACKAGE_PREFIX)
    }

    private fun isSupportedBrowserPackage(packageName: String): Boolean {
        return supportedBrowserPackages.contains(packageName)
    }

    companion object {
        const val PREFS_NAME = "tempus_app_guard"
        const val BLOCKED_WEBSITES_PREF_KEY = "blocked_websites"
        const val CUSTOM_TRACKED_APPS_PREF_KEY = "custom_tracked_apps"
        const val TEN_SECOND_LIMIT_VALUE = -10
        const val INSTAGRAM_PACKAGE_NAME = "com.instagram.android"
        const val YOUTUBE_PACKAGE_NAME = "com.google.android.youtube"
        const val YOUTUBE_REVANCED_PACKAGE_PREFIX = "app.revanced.android.youtube"
        const val INSTAGRAM_REELS_SETTING_KEY = "instagram_reels"
        const val INSTAGRAM_STORIES_SETTING_KEY = "instagram_explore"
        const val YOUTUBE_SHORTS_SETTING_KEY = "youtube_shorts"
        const val TARGET_INSTAGRAM = "instagram"
        const val TARGET_YOUTUBE = "youtube"
        private const val INSTAGRAM_REELS_CONTAINER_VIEW_ID =
            "com.instagram.android:id/clips_video_container"
        private const val INSTAGRAM_DEBUG_TAG = "TempusInstagramDebug"
        private const val YOUTUBE_DEBUG_TAG = "TempusYouTubeDebug"
        private const val PROMPT_DEBUG_TAG = "TempusPromptOverlay"
        private const val BLOCK_RETRY_COUNT = 6
        private const val BLOCK_RETRY_DELAY_MS = 250L
        private const val PROMPT_SUPPRESSION_MILLIS = 800L
        private const val INSTAGRAM_DEBUG_LOGS_ENABLED = false
        private const val YOUTUBE_DEBUG_LOGS_ENABLED = true
        private const val INSTAGRAM_REELS_SCAN_DEBOUNCE_MILLIS = 250L
        private const val INSTAGRAM_REELS_DETECTION_CACHE_MILLIS = 1200L
        private val supportedBrowserPackages = setOf(
            "com.android.chrome",
            "com.chrome.beta",
            "com.chrome.dev",
            "com.brave.browser",
            "com.microsoft.emmx",
            "org.mozilla.firefox",
            "org.mozilla.focus",
            "com.sec.android.app.sbrowser",
            "com.opera.browser",
        )
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
            AppLimit(
                settingKey = "tiktok_app",
                packageNames = setOf("com.zhiliaoapp.musically"),
            ),
            AppLimit(
                settingKey = "snapchat_app",
                packageNames = setOf("com.snapchat.android"),
            ),
            AppLimit(
                settingKey = "facebook_app",
                packageNames = setOf("com.facebook.katana"),
            ),
        )

        @Volatile
        private var promptActive = false

        @Volatile
        private var activeService: AppGuardAccessibilityService? = null

        @Volatile
        private var instagramAllowedUntilMillis = 0L

        @Volatile
        private var youTubeAllowedUntilMillis = 0L

        @Volatile
        private var promptSuppressedUntilMillis = 0L

        fun dismissPrompt() {
            activeService?.dismissPromptOverlay() ?: run {
                promptActive = false
            }
        }

        fun returnToPreviousPageAfterPrompt() {
            promptSuppressedUntilMillis = System.currentTimeMillis() + PROMPT_SUPPRESSION_MILLIS
            activeService?.enforcementHandler?.postDelayed(
                {
                    activeService?.performGlobalAction(GLOBAL_ACTION_BACK)
                },
                150L,
            )
        }

        fun allowTargetForMinutes(target: String, minutes: Int) {
            val allowedUntil = System.currentTimeMillis() + minutes * 60 * 1000L
            when (target.lowercase()) {
                TARGET_YOUTUBE -> {
                    youTubeAllowedUntilMillis = allowedUntil
                }
                else -> {
                    instagramAllowedUntilMillis = allowedUntil
                }
            }
            activeService?.dismissPromptOverlay() ?: run {
                promptActive = false
            }
        }
    }

    private fun getTrackedAppLimits(): List<AppLimit> {
        return buildList {
            addAll(builtInTrackedAppLimits)
            addAll(
                getCustomTrackedApps().map { app ->
                    AppLimit(
                        settingKey = customTrackedAppSettingKey(app.packageName),
                        packageNames = setOf(app.packageName),
                    )
                },
            )
        }
    }

    private fun getCustomTrackedApps(): List<CustomTrackedAppConfig> {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val serialized = prefs.getString(CUSTOM_TRACKED_APPS_PREF_KEY, null) ?: return emptyList()
        val jsonArray = JSONArray(serialized)
        return List(jsonArray.length()) { index ->
            val entry = jsonArray.getJSONObject(index)
            CustomTrackedAppConfig(
                appName = entry.optString("appName"),
                packageName = entry.optString("packageName"),
            )
        }.filter { app ->
            app.packageName.isNotBlank()
        }
    }

    private fun customTrackedAppSettingKey(packageName: String): String {
        return "custom_app_" + packageName.replace(Regex("[^A-Za-z0-9]+"), "_")
    }
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

private data class CustomTrackedAppConfig(
    val appName: String,
    val packageName: String,
)
