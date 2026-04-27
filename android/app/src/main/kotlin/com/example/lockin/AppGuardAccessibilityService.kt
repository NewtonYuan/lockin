package com.example.lockin

import android.accessibilityservice.AccessibilityService
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.util.Calendar

class AppGuardAccessibilityService : AccessibilityService() {
    private var lastForegroundPackage: String? = null
    private val enforcementHandler = Handler(Looper.getMainLooper())

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

        if (packageName != lastForegroundPackage) {
            lastForegroundPackage = packageName
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

        if (promptActive || isInstagramAllowed()) return
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
        super.onDestroy()
    }

    private fun isInstagramAllowed(): Boolean {
        val now = System.currentTimeMillis()
        return now < instagramAllowedUntilMillis || now < promptSuppressedUntilMillis
    }

    private fun shouldBlockPackage(packageName: String): Boolean {
        val appLimit = trackedAppLimits.firstOrNull { appLimit ->
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

    private fun getTodayForegroundMillis(appLimit: AppLimit): Long {
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
        val totalMillis = stats
            .filter { usage -> appLimit.matches(usage.packageName) }
            .sumOf { usage -> usage.totalTimeInForeground }
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

    private fun openInstagramPrompt() {
        promptActive = true
        startActivity(
            Intent(this, ConfirmInstagramActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                addFlags(Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
            },
        )
    }

    private fun openYouTubePrompt() {
        promptActive = true
        startActivity(
            Intent(this, ConfirmInstagramActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                addFlags(Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
            },
        )
    }

    private fun shouldOpenInstagramBlockPrompt(
        event: AccessibilityEvent,
        eventType: Int,
    ): Boolean {
        if (isInstagramReelsBlockingEnabled()) {
            if (eventType == AccessibilityEvent.TYPE_VIEW_CLICKED && isReelsClick(event)) {
                return true
            }
            if (
                eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED &&
                isReelsContentScreen()
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

    private fun isReelsClick(event: AccessibilityEvent): Boolean {
        val clickedLabel = buildString {
            event.text.forEach { append(' ').append(it) }
            append(' ').append(event.contentDescription?.toString().orEmpty())
        }.trim()

        return clickedLabel.equals("reels", ignoreCase = true) ||
            clickedLabel.startsWith("Reel by ", ignoreCase = true)
    }

    private fun isReelsContentScreen(): Boolean {
        val rootNode = rootInActiveWindow ?: return false
        val rootText = buildNodeText(rootNode)
            .replace(Regex("\\s+"), " ")
            .trim()
        return rootText.startsWith("Reel by ", ignoreCase = true)
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

    companion object {
        const val PREFS_NAME = "tempus_app_guard"
        const val TEN_SECOND_LIMIT_VALUE = -10
        const val INSTAGRAM_PACKAGE_NAME = "com.instagram.android"
        const val YOUTUBE_PACKAGE_NAME = "com.google.android.youtube"
        const val YOUTUBE_REVANCED_PACKAGE_PREFIX = "app.revanced.android.youtube"
        const val INSTAGRAM_REELS_SETTING_KEY = "instagram_reels"
        const val INSTAGRAM_STORIES_SETTING_KEY = "instagram_explore"
        const val YOUTUBE_SHORTS_SETTING_KEY = "youtube_shorts"
        private const val INSTAGRAM_DEBUG_TAG = "TempusInstagramDebug"
        private const val YOUTUBE_DEBUG_TAG = "TempusYouTubeDebug"
        private const val BLOCK_RETRY_COUNT = 6
        private const val BLOCK_RETRY_DELAY_MS = 250L
        private const val PROMPT_SUPPRESSION_MILLIS = 800L
        private const val INSTAGRAM_DEBUG_LOGS_ENABLED = true
        private const val YOUTUBE_DEBUG_LOGS_ENABLED = true
        private val trackedAppLimits = listOf(
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
        private var promptSuppressedUntilMillis = 0L

        fun dismissPrompt() {
            promptActive = false
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

        fun allowInstagramForMinutes(minutes: Int) {
            instagramAllowedUntilMillis = System.currentTimeMillis() + minutes * 60 * 1000L
            promptActive = false
        }
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
