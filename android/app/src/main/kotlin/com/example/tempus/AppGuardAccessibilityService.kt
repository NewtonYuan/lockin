package com.prestige.tempus

import android.accessibilityservice.AccessibilityService
import android.app.ActivityManager
import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Rect
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.SystemClock
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.text.SpannableString
import android.text.Spanned
import android.text.style.StyleSpan
import android.text.style.ForegroundColorSpan
import android.graphics.Typeface
import java.util.Calendar
import java.util.concurrent.ConcurrentHashMap
import org.json.JSONArray
import org.json.JSONObject

class AppGuardAccessibilityService : AccessibilityService() {
    private var lastForegroundPackage: String? = null
    private val enforcementHandler = Handler(Looper.getMainLooper())
    private val usageAccessEnableWatcher = object : Runnable {
        override fun run() {
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val awaitingEnable = prefs.getBoolean(AWAITING_USAGE_ACCESS_ENABLE_PREF_KEY, false)
            if (!awaitingEnable) return
            if (isUsageAccessEnabled()) {
                prefs.edit()
                    .putBoolean(AWAITING_USAGE_ACCESS_ENABLE_PREF_KEY, false)
                    .putBoolean(USAGE_ACCESS_ENABLED_SUCCESS_PREF_KEY, true)
                    .apply()
                relaunchAppToForeground()
                return
            }
            enforcementHandler.postDelayed(this, USAGE_ACCESS_WATCH_INTERVAL_MILLIS)
        }
    }
    private var promptTarget: String? = null
    private var promptPackageName: String? = null
    private var currentWebsiteContext: WebsiteContext? = null
    private var lastBlockedWebsiteDomain: String? = null
    private var lastBlockedWebsitePackage: String? = null
    private var lastInstagramReelsScanAtMillis = 0L
    private var instagramReelsDetectedUntilMillis = 0L
    private var instagramAllowedDmReelFingerprint: String? = null
    private var instagramExploreOverlayView: View? = null
    private var instagramExploreOverlayRect: Rect? = null
    private var lastInstagramExploreDetectionState: Boolean? = null
    private var lastInstagramExploreDetectionReason: String? = null
    private var instagramExplorePositiveHitCount = 0
    private var instagramExploreMissCount = 0
    private var instagramExploreMissStartedAtElapsedRealtime = 0L
    private var instagramExploreRevalidationRunning = false
    private val instagramExploreRevalidationRunnable = Runnable {
        revalidateInstagramExploreFeedOverlay()
    }
    private var lastYouTubeShortsScanAtMillis = 0L
    private var youTubeShortsDetectedUntilMillis = 0L
    private var lastSnapchatSpotlightScanAtMillis = 0L
    private var snapchatSpotlightDetectedUntilMillis = 0L

    override fun onServiceConnected() {
        activeService = this
        handleAccessibilityEnabledReturn()
        startUsageAccessEnableWatcherIfNeeded()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val eventType = event?.eventType ?: return
        if (
            eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            eventType != AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED &&
            eventType != AccessibilityEvent.TYPE_VIEW_CLICKED &&
            eventType != AccessibilityEvent.TYPE_VIEW_SCROLLED &&
            eventType != AccessibilityEvent.TYPE_WINDOWS_CHANGED
        ) {
            return
        }

        val rawPackageName = event.packageName?.toString() ?: return
        val packageName = if (shouldIgnoreOverlayTransientPackage(rawPackageName)) {
            lastForegroundPackage ?: rawPackageName
        } else {
            rawPackageName
        }
        val previousPackageName = lastForegroundPackage
        val packageChanged = previousPackageName != packageName
        if (packageName != lastForegroundPackage) {
            lastForegroundPackage = packageName
            if (previousPackageName != null) {
                handleWebsitePackageTransition(previousPackageName, packageName)
            } else if (packageName == this.packageName) {
                clearWebsiteContext()
            }
            if (packageName != INSTAGRAM_PACKAGE_NAME) {
                clearInstagramReelsDetectionCache()
                clearInstagramDmAllowedReel()
                dismissInstagramExploreFeedOverlay()
            }
            if (!isYouTubePackage(packageName)) {
                clearYouTubeShortsDetectionCache()
            }
            if (packageName != SNAPCHAT_PACKAGE_NAME) {
                clearSnapchatSpotlightDetectionCache()
            }
            if (
                promptActive &&
                promptTarget != null &&
                shouldDismissPromptForPackage(packageName, promptPackageName)
            ) {
                dismissPromptOverlay()
            }
        }
        if (packageName == INSTAGRAM_PACKAGE_NAME) {
            refreshInstagramExploreFeedOverlay()
        } else {
            dismissInstagramExploreFeedOverlay()
        }
        if (packageName == this.packageName) {
            clearWebsiteContext()
            return
        }
        if (isDailyLimitReached(packageName)) {
            if (System.currentTimeMillis() < promptSuppressedUntilMillis) {
                enforceHome(packageName)
                return
            }
            if (!promptActive) {
                openDailyLimitPrompt(packageName)
            }
            return
        }

        if (promptActive || isPackageTemporarilyAllowed(packageName)) return
        if (shouldProcessWebsiteEvent(eventType) && checkForBlockedWebsite(packageName)) {
            return
        }
        if (shouldOpenPauseOnOpenPrompt(packageName, packageChanged)) {
            openPauseOnOpenPrompt(packageName)
            return
        }
        if (packageName == INSTAGRAM_PACKAGE_NAME) {
            if (!shouldOpenInstagramBlockPrompt(event, eventType)) return
            openInstagramPrompt()
            return
        }
        if (isYouTubePackage(packageName)) {
            if (!shouldOpenYouTubeBlockPrompt(packageName, eventType)) return
            openYouTubePrompt()
            return
        }
        if (packageName == SNAPCHAT_PACKAGE_NAME) {
            if (!shouldOpenSnapchatBlockPrompt(eventType)) return
            openSnapchatPrompt()
        }
    }

    override fun onInterrupt() = Unit

    override fun onDestroy() {
        if (activeService === this) {
            activeService = null
        }
        enforcementHandler.removeCallbacks(usageAccessEnableWatcher)
        enforcementHandler.removeCallbacksAndMessages(null)
        dismissPromptState()
        dismissInstagramExploreFeedOverlay()
        super.onDestroy()
    }

    private fun isPackageTemporarilyAllowed(packageName: String): Boolean {
        val now = System.currentTimeMillis()
        if (now < promptSuppressedUntilMillis) return true
        return when {
            packageName == INSTAGRAM_PACKAGE_NAME -> now < instagramAllowedUntilMillis
            isYouTubePackage(packageName) -> now < youTubeAllowedUntilMillis
            packageName == SNAPCHAT_PACKAGE_NAME -> now < snapchatAllowedUntilMillis
            else -> false
        }
    }

    private fun shouldBlockPackage(packageName: String): Boolean {
        if (isDailyLimitTemporarilyAllowed(packageName)) return false
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

    private fun isInstagramExploreFeedHidingEnabled(): Boolean {
        return getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(INSTAGRAM_HIDE_EXPLORE_FEED_SETTING_KEY, false)
    }

    private fun isInstagramReelsDmsAllowed(): Boolean {
        return getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(INSTAGRAM_REELS_DMS_SETTING_KEY, false)
    }

    private fun isYouTubeShortsBlockingEnabled(): Boolean {
        return getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(YOUTUBE_SHORTS_SETTING_KEY, false)
    }

    private fun isSnapchatSpotlightBlockingEnabled(): Boolean {
        return getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(SNAPCHAT_SPOTLIGHT_SETTING_KEY, false)
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

    private fun openInstagramPrompt() {
        promptActive = true
        recordStatsEvent(
            eventType = STATS_EVENT_REELS_BLOCK,
            packageName = lastForegroundPackage ?: INSTAGRAM_PACKAGE_NAME,
            target = TARGET_INSTAGRAM,
        )
        showPromptActivity(
            target = TARGET_INSTAGRAM,
            sourcePackageName = lastForegroundPackage,
            appLabel = "Instagram",
        )
    }

    private fun openYouTubePrompt() {
        promptActive = true
        recordStatsEvent(
            eventType = STATS_EVENT_SHORTS_BLOCK,
            packageName = lastForegroundPackage ?: YOUTUBE_PACKAGE_NAME,
            target = TARGET_YOUTUBE,
        )
        pauseYouTubeShortsPlayback(lastForegroundPackage)
        showPromptActivity(
            target = TARGET_YOUTUBE,
            sourcePackageName = lastForegroundPackage,
            appLabel = "YouTube",
        )
    }

    private fun openSnapchatPrompt() {
        promptActive = true
        recordStatsEvent(
            eventType = STATS_EVENT_SPOTLIGHT_BLOCK,
            packageName = lastForegroundPackage ?: SNAPCHAT_PACKAGE_NAME,
            target = TARGET_SNAPCHAT,
        )
        showPromptActivity(
            target = TARGET_SNAPCHAT,
            sourcePackageName = lastForegroundPackage,
            appLabel = "Snapchat",
        )
    }

    private fun openPauseOnOpenPrompt(packageName: String) {
        promptActive = true
        recordStatsEvent(
            eventType = STATS_EVENT_PAUSE_ON_OPEN_PROMPT,
            packageName = packageName,
            target = packageName,
        )
        showPauseOnOpenActivity(
            sourcePackageName = packageName,
            appLabel = getTrackedAppPromptLabel(packageName),
        )
    }

    private fun openDailyLimitPrompt(packageName: String) {
        promptActive = true
        recordStatsEvent(
            eventType = STATS_EVENT_DAILY_LIMIT_HIT,
            packageName = packageName,
            target = packageName,
        )
        showDailyLimitReachedActivity(
            sourcePackageName = packageName,
            appLabel = getTrackedAppPromptLabel(packageName),
        )
    }

    private fun showPromptActivity(
        target: String,
        sourcePackageName: String?,
        appLabel: String,
        websiteDomain: String? = null,
    ) {
        enforcementHandler.post {
            promptTarget = target
            promptPackageName = sourcePackageName
            val intent = Intent(this, ConfirmBlockerActivity::class.java).apply {
                putExtra(ConfirmBlockerActivity.EXTRA_TARGET, target)
                putExtra(ConfirmBlockerActivity.EXTRA_APP_LABEL, appLabel)
                if (!websiteDomain.isNullOrBlank()) {
                    putExtra(ConfirmBlockerActivity.EXTRA_WEBSITE_DOMAIN, websiteDomain)
                }
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
        promptPackageName = null
        promptActive = false
    }

    private fun dismissPromptOverlay() {
        enforcementHandler.post {
            dismissPromptState()
        }
    }

    private fun shouldDismissPromptForPackage(
        packageName: String,
        sourcePackageName: String?,
    ): Boolean {
        if (packageName == this.packageName) return false
        if (packageName == "android") return false
        if (packageName == "com.android.systemui") return false
        if (sourcePackageName.isNullOrBlank()) return true
        return packageName != sourcePackageName
    }

    private fun shouldProcessWebsiteEvent(eventType: Int): Boolean {
        return eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED ||
            eventType == AccessibilityEvent.TYPE_WINDOWS_CHANGED
    }

    private fun handleWebsitePackageTransition(
        previousPackageName: String,
        packageName: String,
    ) {
        val context = currentWebsiteContext ?: return
        if (packageName == this.packageName) {
            clearWebsiteContext()
            return
        }
        if (context.packageName != previousPackageName) return
        if (packageName != previousPackageName) {
            clearWebsiteContext()
        }
    }

    private fun checkForBlockedWebsite(packageName: String): Boolean {
        if (!WebsiteBlockingSupport.isSupportedBrowserPackage(packageName)) {
            return false
        }
        val activeRoot = rootInActiveWindow ?: return false
        val activeRootPackageName = activeRoot.packageName?.toString()
        if (activeRootPackageName != packageName) {
            return false
        }

        val observation = WebsiteBlockingSupport.extractObservedDomain(
            rootNode = activeRoot,
            packageName = packageName,
            subtreeTextExtractor = ::buildNodeText,
        )

        if (observation == null) {
            closeObservedWebsiteForPackage(packageName)
            return false
        }
        if (observation.isEditingAddressBar) {
            closeObservedWebsiteForPackage(packageName)
            return false
        }
        val observedDomain = observation.domain

        val enabledDomains = getBlockedWebsiteRules()
            .asSequence()
            .filter { rule -> rule.isEnabled }
            .map { rule -> rule.domain }
            .filter { domain -> domain.isNotBlank() }
            .toList()

        val matchedBlockedDomain =
            WebsiteBlockingSupport.findMatchingBlockedDomain(enabledDomains, observedDomain)
        updateWebsiteContext(
            packageName = packageName,
            observedDomain = observedDomain,
            matchedBlockedDomain = matchedBlockedDomain,
        )

        if (matchedBlockedDomain.isNullOrBlank()) return false
        if (isWebsiteTemporarilyAllowed(matchedBlockedDomain)) return false
        if (
            matchedBlockedDomain == lastBlockedWebsiteDomain &&
            packageName == lastBlockedWebsitePackage
        ) {
            return false
        }

        openWebsitePrompt(
            packageName = packageName,
            blockedDomain = matchedBlockedDomain,
        )
        return true
    }

    private fun updateWebsiteContext(
        packageName: String,
        observedDomain: String,
        matchedBlockedDomain: String?,
    ) {
        val normalizedObserved = WebsiteBlockingSupport.normalizeObservedInput(observedDomain)
        if (normalizedObserved.isBlank()) {
            clearWebsiteContext()
            return
        }

        val normalizedMatched = matchedBlockedDomain
            ?.let(WebsiteBlockingSupport::normalizeObservedInput)
            ?.takeIf { it.isNotBlank() }
        val previous = currentWebsiteContext
        if (
            previous?.packageName == packageName &&
            previous.observedDomain == normalizedObserved &&
            previous.matchedBlockedDomain == normalizedMatched
        ) {
            return
        }

        currentWebsiteContext = WebsiteContext(
            packageName = packageName,
            observedDomain = normalizedObserved,
            matchedBlockedDomain = normalizedMatched,
        )
    }

    private fun closeObservedWebsiteForPackage(packageName: String) {
        if (currentWebsiteContext?.packageName == packageName) {
            clearWebsiteContext()
        }
    }

    private fun clearWebsiteContext() {
        currentWebsiteContext = null
        lastBlockedWebsiteDomain = null
        lastBlockedWebsitePackage = null
    }

    private fun getBlockedWebsiteRules(): List<BlockedWebsiteRule> {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val serialized = prefs.getString(BLOCKED_WEBSITES_PREF_KEY, null) ?: return emptyList()
        return runCatching {
            val jsonArray = JSONArray(serialized)
            List(jsonArray.length()) { index ->
                val entry = jsonArray.getJSONObject(index)
                BlockedWebsiteRule(
                    domain = WebsiteBlockingSupport.normalizeObservedInput(
                        entry.optString("domain"),
                    ),
                    isEnabled = entry.optBoolean("isEnabled", true),
                )
            }.filter { rule -> rule.domain.isNotBlank() }
        }.getOrDefault(emptyList())
    }

    private fun isWebsiteTemporarilyAllowed(blockedDomain: String): Boolean {
        val normalizedDomain = WebsiteBlockingSupport.normalizeObservedInput(blockedDomain)
        if (normalizedDomain.isBlank()) return false
        val allowedUntil = websiteAllowedUntilMillisByDomain[normalizedDomain] ?: return false
        val now = System.currentTimeMillis()
        if (now >= allowedUntil) {
            websiteAllowedUntilMillisByDomain.remove(normalizedDomain)
            return false
        }
        return true
    }

    private fun openWebsitePrompt(
        packageName: String,
        blockedDomain: String,
    ) {
        promptActive = true
        lastBlockedWebsiteDomain = blockedDomain
        lastBlockedWebsitePackage = packageName
        recordStatsEvent(
            eventType = STATS_EVENT_WEBSITE_BLOCK,
            packageName = packageName,
            target = TARGET_WEBSITE,
            metadata = JSONObject().apply {
                put("domain", blockedDomain)
            },
        )
        showPromptActivity(
            target = TARGET_WEBSITE,
            sourcePackageName = packageName,
            appLabel = blockedDomain,
            websiteDomain = blockedDomain,
        )
    }

    private fun shouldIgnoreOverlayTransientPackage(packageName: String): Boolean {
        return packageName == this.packageName ||
            packageName == "android" ||
            packageName == "com.android.systemui"
    }

    private fun shouldOpenPauseOnOpenPrompt(
        packageName: String,
        packageChanged: Boolean,
    ): Boolean {
        if (!packageChanged) return false
        if (packageName == this.packageName) return false
        if (packageName == "android") return false
        if (packageName == "com.android.systemui") return false
        if (isPauseOnOpenTemporarilyAllowed(packageName)) return false
        return isPauseOnOpenEnabledForPackage(packageName)
    }

    private fun isPauseOnOpenTemporarilyAllowed(packageName: String): Boolean {
        val allowedUntil = pauseOnOpenAllowedUntilMillisByPackage[packageName] ?: return false
        val now = System.currentTimeMillis()
        if (now >= allowedUntil) {
            pauseOnOpenAllowedUntilMillisByPackage.remove(packageName)
            return false
        }
        return true
    }

    private fun isPauseOnOpenEnabledForPackage(packageName: String): Boolean {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return when {
            packageName == INSTAGRAM_PACKAGE_NAME -> {
                prefs.getBoolean(INSTAGRAM_PAUSE_ON_OPEN_SETTING_KEY, false)
            }
            packageName == SNAPCHAT_PACKAGE_NAME -> {
                prefs.getBoolean(SNAPCHAT_PAUSE_ON_OPEN_SETTING_KEY, false)
            }
            isYouTubePackage(packageName) -> {
                prefs.getBoolean(YOUTUBE_PAUSE_ON_OPEN_SETTING_KEY, false)
            }
            else -> {
                prefs.getBoolean(customTrackedAppPauseOnOpenSettingKey(packageName), false)
            }
        }
    }

    private fun showPauseOnOpenActivity(
        sourcePackageName: String,
        appLabel: String,
    ) {
        enforcementHandler.post {
            promptTarget = TARGET_PAUSE_ON_OPEN
            promptPackageName = sourcePackageName
            val intent = Intent(this, PauseOnOpenActivity::class.java).apply {
                putExtra(PauseOnOpenActivity.EXTRA_SOURCE_PACKAGE_NAME, sourcePackageName)
                putExtra(PauseOnOpenActivity.EXTRA_APP_LABEL, appLabel)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            runCatching {
                startActivity(intent)
                Log.d(PROMPT_DEBUG_TAG, "Showing pause-on-open activity for package=$sourcePackageName")
            }.onFailure {
                Log.e(PROMPT_DEBUG_TAG, "Failed to show pause-on-open activity", it)
                dismissPromptState()
            }
        }
    }

    private fun showDailyLimitReachedActivity(
        sourcePackageName: String,
        appLabel: String,
    ) {
        enforcementHandler.post {
            promptTarget = TARGET_DAILY_LIMIT
            promptPackageName = sourcePackageName
            val intent = Intent(this, DailyLimitReachedActivity::class.java).apply {
                putExtra(DailyLimitReachedActivity.EXTRA_SOURCE_PACKAGE_NAME, sourcePackageName)
                putExtra(DailyLimitReachedActivity.EXTRA_APP_LABEL, appLabel)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            runCatching {
                startActivity(intent)
                Log.d(PROMPT_DEBUG_TAG, "Showing daily limit activity for package=$sourcePackageName")
            }.onFailure {
                Log.e(PROMPT_DEBUG_TAG, "Failed to show daily limit activity", it)
                dismissPromptState()
            }
        }
    }

    private fun getTrackedAppPromptLabel(packageName: String): String {
        return when {
            packageName == INSTAGRAM_PACKAGE_NAME -> "Instagram"
            packageName == SNAPCHAT_PACKAGE_NAME -> "Snapchat"
            isYouTubePackage(packageName) -> "YouTube"
            else -> {
                getCustomTrackedApps()
                    .firstOrNull { app -> app.packageName == packageName }
                    ?.appName
                    ?.takeIf { it.isNotBlank() }
                    ?: packageName
            }
        }
    }

    private fun isDailyLimitTemporarilyAllowed(packageName: String): Boolean {
        val allowedUntil = dailyLimitAllowedUntilMillisByPackage[packageName] ?: return false
        val now = System.currentTimeMillis()
        if (now >= allowedUntil) {
            dailyLimitAllowedUntilMillisByPackage.remove(packageName)
            return false
        }
        return true
    }

    private fun isDailyLimitReached(packageName: String): Boolean {
        return shouldBlockPackage(packageName)
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
                val reelFingerprint = buildCurrentInstagramReelFingerprint()
                if (isInstagramReelsDmsAllowed() && isInstagramDmThreadContext()) {
                    instagramAllowedDmReelFingerprint = reelFingerprint
                    return false
                }
                if (
                    reelFingerprint != null &&
                    reelFingerprint == instagramAllowedDmReelFingerprint
                ) {
                    return false
                }
                if (
                    instagramAllowedDmReelFingerprint != null &&
                    reelFingerprint != instagramAllowedDmReelFingerprint
                ) {
                    clearInstagramDmAllowedReel()
                }
                return true
            }
            clearInstagramDmAllowedReel()
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
        packageName: String,
        eventType: Int,
    ): Boolean {
        if (isYouTubeShortsBlockingEnabled()) {
            if (
                (eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED ||
                    eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) &&
                isYouTubeShortsScreen(packageName)
            ) {
                return true
            }
        }
        return false
    }

    private fun shouldOpenSnapchatBlockPrompt(eventType: Int): Boolean {
        if (!isSnapchatSpotlightBlockingEnabled()) return false
        if (
            eventType != AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED &&
            eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
        ) {
            return false
        }
        return isSnapchatSpotlightScreen()
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

    private fun clearInstagramDmAllowedReel() {
        instagramAllowedDmReelFingerprint = null
    }

    private fun isInstagramDmThreadContext(): Boolean {
        val rootNode = rootInActiveWindow ?: return false
        return instagramDmThreadViewIds.any { viewId ->
            val nodes = rootNode.findAccessibilityNodeInfosByViewId(viewId) ?: return@any false
            nodes.any { node ->
                node?.isVisibleToUser == true &&
                    !node.isContentInvalid &&
                    node.viewIdResourceName == viewId
            }
        }
    }

    private fun buildCurrentInstagramReelFingerprint(): String? {
        val rootNode = rootInActiveWindow ?: return null
        val reelNode = findVisibleNodeByViewId(rootNode, INSTAGRAM_REELS_ROOT_LAYOUT_VIEW_ID)
            ?: findVisibleNodeByViewId(rootNode, INSTAGRAM_REELS_CONTAINER_VIEW_ID)
            ?: return null

        val authorText = findVisibleNodeText(rootNode, INSTAGRAM_REELS_AUTHOR_USERNAME_VIEW_ID)
        val likeCountText = findVisibleNodeText(rootNode, INSTAGRAM_REELS_LIKE_COUNT_VIEW_ID)
        val reelText = buildNodeText(reelNode)
            .replace(Regex("\\s+"), " ")
            .trim()

        val fingerprintParts = listOf(authorText, likeCountText, reelText)
            .mapNotNull { value -> value?.trim()?.takeIf { it.isNotBlank() } }
        if (fingerprintParts.isEmpty()) return null
        return fingerprintParts.joinToString(separator = "|").take(600)
    }

    private fun findVisibleNodeByViewId(
        rootNode: AccessibilityNodeInfo,
        viewId: String,
    ): AccessibilityNodeInfo? {
        val nodes = rootNode.findAccessibilityNodeInfosByViewId(viewId) ?: return null
        return nodes.firstOrNull { node ->
            node?.isVisibleToUser == true &&
                !node.isContentInvalid &&
                node.viewIdResourceName == viewId
        }
    }

    private fun findVisibleNodeText(
        rootNode: AccessibilityNodeInfo,
        viewId: String,
    ): String? {
        val node = findVisibleNodeByViewId(rootNode, viewId) ?: return null
        val text = node.text?.toString()?.trim()
        if (!text.isNullOrBlank()) return text
        val description = node.contentDescription?.toString()?.trim()
        if (!description.isNullOrBlank()) return description
        return buildNodeText(node)
            .replace(Regex("\\s+"), " ")
            .trim()
            .takeIf { it.isNotBlank() }
    }

    private fun refreshInstagramExploreFeedOverlay() {
        val exploreFeedHidingEnabled = isInstagramExploreFeedHidingEnabled()
        if (!exploreFeedHidingEnabled) {
            logInstagramExploreDetection(
                detected = false,
                reason = "setting_disabled",
            )
            resetInstagramExplorePositiveState()
            dismissInstagramExploreFeedOverlay()
            return
        }

        val rootNode = rootInActiveWindow ?: run {
            handleInstagramExploreDetectionMiss("no_root_node")
            return
        }
        if (isInstagramKnownNotExploreScreen(rootNode)) {
            handleInstagramExploreDetectionMiss("known_not_explore_view")
            return
        }
        val detection = findInstagramExploreFeedDetection(rootNode) ?: run {
            handleInstagramExploreDetectionMiss("no_explore_rect")
            return
        }
        if (instagramExploreOverlayView == null) {
            instagramExplorePositiveHitCount += 1
            if (instagramExplorePositiveHitCount < INSTAGRAM_EXPLORE_POSITIVE_HIT_THRESHOLD) {
                logInstagramExploreLifecycle(
                    "pending_show source=${detection.source} rect=${formatRectForLog(detection.rect)} hits=$instagramExplorePositiveHitCount",
                )
                scheduleInstagramExploreRevalidation(INSTAGRAM_EXPLORE_SHOW_CONFIRM_MILLIS)
                return
            }
        }
        resetInstagramExplorePositiveState()
        resetInstagramExploreMissState()
        scheduleInstagramExploreRevalidation(INSTAGRAM_EXPLORE_REVALIDATION_MILLIS)
        logInstagramExploreDetection(
            detected = true,
            reason = "${detection.source}:${formatRectForLog(detection.rect)}",
        )
        logInstagramExploreLifecycle(
            if (instagramExploreOverlayView == null) {
                "show_overlay source=${detection.source} rect=${formatRectForLog(detection.rect)}"
            } else {
                "keep_overlay source=${detection.source} rect=${formatRectForLog(detection.rect)}"
            },
        )
        showOrUpdateInstagramExploreFeedOverlay(detection.rect)
    }

    private fun findInstagramExploreFeedDetection(
        rootNode: AccessibilityNodeInfo,
    ): InstagramExploreDetection? {
        val actionBarRect = findVisibleNodeBounds(rootNode, INSTAGRAM_EXPLORE_ACTION_BAR_VIEW_ID)
        val feedRect = if (actionBarRect != null) {
            findVisibleNodeBounds(rootNode, INSTAGRAM_EXPLORE_RECYCLER_VIEW_ID)
                ?: findVisibleNodeBounds(
                    rootNode,
                    INSTAGRAM_EXPLORE_REFRESHABLE_CONTAINER_VIEW_ID,
                )
        } else {
            null
        }
        if (actionBarRect != null && feedRect != null) {
            if (feedRect.width() <= 0 || feedRect.bottom <= actionBarRect.bottom) return null
            return InstagramExploreDetection(
                rect = Rect(
                    feedRect.left,
                    actionBarRect.bottom,
                    feedRect.right,
                    feedRect.bottom,
                ),
                source = "feed_container",
            )
        }
        return null
    }

    private fun isInstagramKnownNotExploreScreen(rootNode: AccessibilityNodeInfo): Boolean {
        return instagramNotExploreViewIds.any { viewId ->
            findVisibleNodeByViewId(rootNode, viewId) != null
        }
    }

    private fun findVisibleNodeBounds(
        rootNode: AccessibilityNodeInfo,
        viewId: String,
    ): Rect? {
        val node = findVisibleNodeByViewId(rootNode, viewId) ?: return null
        val bounds = Rect()
        node.getBoundsInScreen(bounds)
        if (bounds.width() <= 0 || bounds.height() <= 0) return null
        return bounds
    }

    private fun showOrUpdateInstagramExploreFeedOverlay(overlayRect: Rect) {
        runOnMainThread {
            val windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val existingView = instagramExploreOverlayView
            val layoutParams = existingView?.layoutParams as? WindowManager.LayoutParams

            if (existingView != null && layoutParams != null) {
                if (areRectsClose(instagramExploreOverlayRect, overlayRect)) return@runOnMainThread
                layoutParams.x = overlayRect.left
                layoutParams.y = overlayRect.top
                layoutParams.width = overlayRect.width()
                layoutParams.height = overlayRect.height()
                runCatching {
                    windowManager.updateViewLayout(existingView, layoutParams)
                    instagramExploreOverlayRect = Rect(overlayRect)
                }.onFailure {
                    dismissInstagramExploreFeedOverlay()
                }
                return@runOnMainThread
            }

            val overlayView = FrameLayout(this).apply {
                setBackgroundColor(Color.BLACK)
                isClickable = true
                isLongClickable = true
                isFocusable = false
                importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
                setOnTouchListener { _, _: MotionEvent -> true }
                addView(instagramExploreOverlayContent(), instagramExploreOverlayContentLayoutParams())
            }
            val params = WindowManager.LayoutParams(
                overlayRect.width(),
                overlayRect.height(),
                overlayRect.left,
                overlayRect.top,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                INSTAGRAM_EXPLORE_OVERLAY_FLAGS,
                PixelFormat.OPAQUE,
            ).apply {
                gravity = Gravity.TOP or Gravity.START
            }

            runCatching {
                windowManager.addView(overlayView, params)
                instagramExploreOverlayView = overlayView
                instagramExploreOverlayRect = Rect(overlayRect)
            }.onFailure {
                instagramExploreOverlayView = null
                instagramExploreOverlayRect = null
            }
        }
    }

    private fun dismissInstagramExploreFeedOverlay() {
        cancelInstagramExploreRevalidation()
        resetInstagramExploreMissState()
        resetInstagramExplorePositiveState()
        runOnMainThread {
            val overlayView = instagramExploreOverlayView ?: run {
                instagramExploreOverlayRect = null
                return@runOnMainThread
            }
            logInstagramExploreLifecycle("remove_overlay")
            instagramExploreOverlayView = null
            instagramExploreOverlayRect = null
            runCatching {
                val windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
                windowManager.removeView(overlayView)
            }
        }
    }

    private fun handleInstagramExploreDetectionMiss(reason: String) {
        logInstagramExploreDetection(
            detected = false,
            reason = reason,
        )
        if (instagramExploreOverlayView == null) {
            resetInstagramExplorePositiveState()
            dismissInstagramExploreFeedOverlay()
            return
        }
        val now = SystemClock.elapsedRealtime()
        if (instagramExploreMissStartedAtElapsedRealtime == 0L) {
            instagramExploreMissStartedAtElapsedRealtime = now
        }
        instagramExploreMissCount += 1
        when {
            instagramExploreMissCount < INSTAGRAM_EXPLORE_MISS_THRESHOLD -> {
                logInstagramExploreLifecycle(
                    "keep_overlay_retry reason=$reason misses=$instagramExploreMissCount",
                )
                scheduleInstagramExploreRevalidation(INSTAGRAM_EXPLORE_RETRY_MILLIS)
            }
            now - instagramExploreMissStartedAtElapsedRealtime <
                INSTAGRAM_EXPLORE_MISS_GRACE_MILLIS -> {
                logInstagramExploreLifecycle(
                    "keep_overlay_grace reason=$reason misses=$instagramExploreMissCount elapsed=${now - instagramExploreMissStartedAtElapsedRealtime}",
                )
                scheduleInstagramExploreRevalidation(INSTAGRAM_EXPLORE_REVALIDATION_MILLIS)
            }
            else -> {
                logInstagramExploreLifecycle(
                    "dismiss_after_miss reason=$reason misses=$instagramExploreMissCount elapsed=${now - instagramExploreMissStartedAtElapsedRealtime}",
                )
                dismissInstagramExploreFeedOverlay()
            }
        }
    }

    private fun revalidateInstagramExploreFeedOverlay() {
        if (instagramExploreRevalidationRunning) return
        instagramExploreRevalidationRunning = true
        try {
            if (lastForegroundPackage != INSTAGRAM_PACKAGE_NAME) {
                dismissInstagramExploreFeedOverlay()
                return
            }
            refreshInstagramExploreFeedOverlay()
        } finally {
            instagramExploreRevalidationRunning = false
        }
    }

    private fun scheduleInstagramExploreRevalidation(delayMillis: Long) {
        enforcementHandler.removeCallbacks(instagramExploreRevalidationRunnable)
        enforcementHandler.postDelayed(instagramExploreRevalidationRunnable, delayMillis)
    }

    private fun cancelInstagramExploreRevalidation() {
        enforcementHandler.removeCallbacks(instagramExploreRevalidationRunnable)
    }

    private fun resetInstagramExploreMissState() {
        instagramExploreMissCount = 0
        instagramExploreMissStartedAtElapsedRealtime = 0L
    }

    private fun resetInstagramExplorePositiveState() {
        instagramExplorePositiveHitCount = 0
    }

    private fun instagramExploreOverlayContent(): LinearLayout {
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
            addView(
                instagramExploreOverlayLogo(),
                LinearLayout.LayoutParams(dp(112), dp(112)).apply {
                    gravity = Gravity.CENTER_HORIZONTAL
                    bottomMargin = dp(18)
                },
            )
            addView(
                TextView(this@AppGuardAccessibilityService).apply {
                    text = instagramExploreOverlayMessage()
                    gravity = Gravity.CENTER
                    setTextColor(Color.WHITE)
                    textSize = 15f
                    setLineSpacing(0f, 1.15f)
                    setPadding(dp(20), 0, dp(20), 0)
                },
                LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                ),
            )
        }
    }

    private fun instagramExploreOverlayLogo(): FrameLayout {
        return FrameLayout(this).apply {
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
            addView(
                ImageView(this@AppGuardAccessibilityService).apply {
                    setImageResource(R.drawable.launch_logo)
                    imageTintList = ColorStateList.valueOf(Color.WHITE)
                    scaleType = ImageView.ScaleType.FIT_CENTER
                },
                FrameLayout.LayoutParams(dp(112), dp(112), Gravity.CENTER),
            )
        }
    }

    private fun instagramExploreOverlayContentLayoutParams(): FrameLayout.LayoutParams {
        return FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            Gravity.CENTER,
        )
    }

    private fun instagramExploreOverlayMessage(): CharSequence {
        val text = "Instagram Explore Feed is\nhidden by Tempus"
        val spannable = SpannableString(text)
        val brandStart = text.lastIndexOf("Tempus")
        if (brandStart >= 0) {
            spannable.setSpan(
                ForegroundColorSpan(Color.WHITE),
                brandStart,
                text.length,
                Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
            )
            spannable.setSpan(
                StyleSpan(Typeface.BOLD),
                brandStart,
                text.length,
                Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
            )
        }
        return spannable
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }

    private fun runOnMainThread(action: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            action()
        } else {
            enforcementHandler.post(action)
        }
    }

    private fun areRectsClose(first: Rect?, second: Rect): Boolean {
        if (first == null) return false
        return kotlin.math.abs(first.left - second.left) <= INSTAGRAM_EXPLORE_RECT_TOLERANCE_PX &&
            kotlin.math.abs(first.top - second.top) <= INSTAGRAM_EXPLORE_RECT_TOLERANCE_PX &&
            kotlin.math.abs(first.right - second.right) <= INSTAGRAM_EXPLORE_RECT_TOLERANCE_PX &&
            kotlin.math.abs(first.bottom - second.bottom) <= INSTAGRAM_EXPLORE_RECT_TOLERANCE_PX
    }

    private fun logInstagramExploreDetection(
        detected: Boolean,
        reason: String,
    ) {
        if (
            lastInstagramExploreDetectionState == detected &&
            lastInstagramExploreDetectionReason == reason
        ) {
            return
        }
        lastInstagramExploreDetectionState = detected
        lastInstagramExploreDetectionReason = reason
        Log.d(
            PROMPT_DEBUG_TAG,
            "instagram_explore_detected=$detected reason=$reason package=$lastForegroundPackage",
        )
    }

    private fun logInstagramExploreLifecycle(message: String) {
        Log.d(
            PROMPT_DEBUG_TAG,
            "instagram_explore_overlay $message package=$lastForegroundPackage",
        )
    }

    private fun formatRectForLog(rect: Rect): String {
        return "${rect.left},${rect.top},${rect.right},${rect.bottom}"
    }

    private fun isYouTubeShortsScreen(packageName: String): Boolean {
        val now = System.currentTimeMillis()
        if (now < youTubeShortsDetectedUntilMillis) {
            return true
        }
        if (now - lastYouTubeShortsScanAtMillis < YOUTUBE_SHORTS_SCAN_DEBOUNCE_MILLIS) {
            return false
        }
        lastYouTubeShortsScanAtMillis = now

        val rootNode = rootInActiveWindow ?: return false
        val shortsContainerViewIds = buildYouTubeShortsContainerViewIds(packageName)
        val isDetected = shortsContainerViewIds.any { viewId ->
            val shortsNodes = rootNode.findAccessibilityNodeInfosByViewId(viewId) ?: return@any false
            shortsNodes.any { node ->
                node?.isVisibleToUser == true &&
                    !node.isContentInvalid &&
                    node.viewIdResourceName == viewId
            }
        }

        if (isDetected) {
            youTubeShortsDetectedUntilMillis = now + YOUTUBE_SHORTS_DETECTION_CACHE_MILLIS
        }

        return isDetected
    }

    private fun clearYouTubeShortsDetectionCache() {
        lastYouTubeShortsScanAtMillis = 0L
        youTubeShortsDetectedUntilMillis = 0L
    }

    private fun isSnapchatSpotlightScreen(): Boolean {
        val now = System.currentTimeMillis()
        if (now < snapchatSpotlightDetectedUntilMillis) {
            return true
        }
        if (now - lastSnapchatSpotlightScanAtMillis < SNAPCHAT_SPOTLIGHT_SCAN_DEBOUNCE_MILLIS) {
            return false
        }
        lastSnapchatSpotlightScanAtMillis = now

        val rootNode = rootInActiveWindow ?: return false
        val spotlightNodes = rootNode.findAccessibilityNodeInfosByViewId(
            SNAPCHAT_SPOTLIGHT_CONTAINER_VIEW_ID,
        ) ?: return false

        val isDetected = spotlightNodes.any { node ->
            node?.isVisibleToUser == true &&
                !node.isContentInvalid &&
                node.viewIdResourceName == SNAPCHAT_SPOTLIGHT_CONTAINER_VIEW_ID
        }

        if (isDetected) {
            snapchatSpotlightDetectedUntilMillis = now + SNAPCHAT_SPOTLIGHT_DETECTION_CACHE_MILLIS
        }

        return isDetected
    }

    private fun clearSnapchatSpotlightDetectionCache() {
        lastSnapchatSpotlightScanAtMillis = 0L
        snapchatSpotlightDetectedUntilMillis = 0L
    }

    private fun buildYouTubeShortsContainerViewIds(packageName: String): List<String> {
        val candidates = linkedSetOf<String>()
        candidates.add("$packageName:$YOUTUBE_SHORTS_CONTAINER_VIEW_ID_SUFFIX")
        candidates.add("$YOUTUBE_PACKAGE_NAME:$YOUTUBE_SHORTS_CONTAINER_VIEW_ID_SUFFIX")
        return candidates.toList()
    }

    private fun pauseYouTubeShortsPlayback(packageName: String?) {
        val resolvedPackageName = packageName?.takeIf(::isYouTubePackage) ?: return
        val rootNode = rootInActiveWindow ?: return
        val shortsNode = buildYouTubeShortsContainerViewIds(resolvedPackageName)
            .asSequence()
            .flatMap { viewId ->
                (rootNode.findAccessibilityNodeInfosByViewId(viewId) ?: emptyList()).asSequence()
            }
            .firstOrNull { node ->
                node?.isVisibleToUser == true &&
                    !node.isContentInvalid
            }

        shortsNode?.performAction(AccessibilityNodeInfo.ACTION_CLICK)
    }

    private fun isStoriesContentScreen(): Boolean {
        val rootNode = rootInActiveWindow ?: return false
        val rootText = buildNodeText(rootNode)
            .replace(Regex("\\s+"), " ")
            .trim()
        return rootText.startsWith("Send message or reaction", ignoreCase = true)
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

    private fun recordShortFormBypassWindow(
        target: String,
        startMillis: Long,
        endMillis: Long,
    ) {
        if (endMillis <= startMillis) return

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val existing = prefs.getString(SHORT_FORM_BYPASS_WINDOWS_PREF_KEY, null)
        val windows = JSONArray(existing ?: "[]")
        val trimmedWindows = JSONArray()
        val pruneBeforeMillis = System.currentTimeMillis() - (35L * 24L * 60L * 60L * 1000L)

        for (index in 0 until windows.length()) {
            val entry = windows.optJSONObject(index) ?: continue
            if (entry.optLong("endMillis") >= pruneBeforeMillis) {
                trimmedWindows.put(entry)
            }
        }

        trimmedWindows.put(
            JSONObject().apply {
                put("target", target)
                put("startMillis", startMillis)
                put("endMillis", endMillis)
            },
        )

        prefs.edit()
            .putString(SHORT_FORM_BYPASS_WINDOWS_PREF_KEY, trimmedWindows.toString())
            .apply()
    }

    private fun recordStatsEvent(
        eventType: String,
        packageName: String? = null,
        target: String? = null,
        metadata: JSONObject? = null,
    ) {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val existing = prefs.getString(STATS_EVENT_LOG_PREF_KEY, null)
        val events = JSONArray(existing ?: "[]")
        val trimmedEvents = JSONArray()
        val pruneBeforeMillis =
            System.currentTimeMillis() - (STATS_EVENT_RETENTION_DAYS * 24L * 60L * 60L * 1000L)

        for (index in 0 until events.length()) {
            val entry = events.optJSONObject(index) ?: continue
            if (entry.optLong("timestamp") >= pruneBeforeMillis) {
                trimmedEvents.put(entry)
            }
        }

        trimmedEvents.put(
            JSONObject().apply {
                put("timestamp", System.currentTimeMillis())
                put("type", eventType)
                put("packageName", packageName ?: "")
                put("target", target ?: "")
                put("metadata", metadata ?: JSONObject())
            },
        )

        prefs.edit()
            .putString(STATS_EVENT_LOG_PREF_KEY, trimmedEvents.toString())
            .apply()
    }

    private fun isYouTubePackage(packageName: String): Boolean {
        return packageName == YOUTUBE_PACKAGE_NAME ||
            packageName.startsWith(YOUTUBE_REVANCED_PACKAGE_PREFIX)
    }

    companion object {
        private data class InstagramExploreDetection(
            val rect: Rect,
            val source: String,
        )

        const val PREFS_NAME = "tempus_app_guard"
        const val BLOCKED_WEBSITES_PREF_KEY = "blocked_websites"
        const val CUSTOM_TRACKED_APPS_PREF_KEY = "custom_tracked_apps"
        const val SHORT_FORM_BYPASS_WINDOWS_PREF_KEY = "short_form_bypass_windows"
        const val STATS_EVENT_LOG_PREF_KEY = "stats_event_log"
        const val PAUSE_DURATION_SECONDS_PREF_KEY = "pause_duration_seconds"
        const val DEFAULT_PAUSE_DURATION_SECONDS = 5
        const val STATS_EVENT_RETENTION_DAYS = 90
        const val TEN_SECOND_LIMIT_VALUE = -10
        const val AWAITING_ACCESSIBILITY_ENABLE_PREF_KEY = "awaiting_accessibility_enable"
        const val ACCESSIBILITY_ENABLED_SUCCESS_PREF_KEY = "accessibility_enabled_success"
        const val AWAITING_USAGE_ACCESS_ENABLE_PREF_KEY = "awaiting_usage_access_enable"
        const val USAGE_ACCESS_ENABLED_SUCCESS_PREF_KEY = "usage_access_enabled_success"
        const val INSTAGRAM_PACKAGE_NAME = "com.instagram.android"
        const val SNAPCHAT_PACKAGE_NAME = "com.snapchat.android"
        const val YOUTUBE_PACKAGE_NAME = "com.google.android.youtube"
        const val YOUTUBE_REVANCED_PACKAGE_PREFIX = "app.revanced.android.youtube"
        const val INSTAGRAM_REELS_SETTING_KEY = "instagram_reels"
        const val INSTAGRAM_REELS_DMS_SETTING_KEY = "instagram_reels_dms"
        const val INSTAGRAM_PAUSE_ON_OPEN_SETTING_KEY = "instagram_pause_on_open"
        const val INSTAGRAM_STORIES_SETTING_KEY = "instagram_explore"
        const val INSTAGRAM_HIDE_EXPLORE_FEED_SETTING_KEY = "instagram_hide_explore_feed"
        const val SNAPCHAT_PAUSE_ON_OPEN_SETTING_KEY = "snapchat_pause_on_open"
        const val SNAPCHAT_SPOTLIGHT_SETTING_KEY = "snapchat_spotlight"
        const val YOUTUBE_PAUSE_ON_OPEN_SETTING_KEY = "youtube_pause_on_open"
        const val YOUTUBE_SHORTS_SETTING_KEY = "youtube_shorts"
        const val TARGET_INSTAGRAM = "instagram"
        const val TARGET_SNAPCHAT = "snapchat"
        const val TARGET_YOUTUBE = "youtube"
        const val TARGET_WEBSITE = "website"
        const val TARGET_PAUSE_ON_OPEN = "pause_on_open"
        const val TARGET_DAILY_LIMIT = "daily_limit"
        const val STATS_EVENT_REELS_BLOCK = "reels_block"
        const val STATS_EVENT_SPOTLIGHT_BLOCK = "spotlight_block"
        const val STATS_EVENT_SHORTS_BLOCK = "shorts_block"
        const val STATS_EVENT_WEBSITE_BLOCK = "website_block"
        const val STATS_EVENT_PAUSE_ON_OPEN_PROMPT = "pause_on_open_prompt"
        const val STATS_EVENT_DAILY_LIMIT_HIT = "daily_limit_hit"
        const val STATS_EVENT_SHORT_FORM_BYPASS = "short_form_bypass"
        const val STATS_EVENT_WEBSITE_BYPASS = "website_bypass"
        const val STATS_EVENT_PAUSE_ON_OPEN_BYPASS = "pause_on_open_bypass"
        const val STATS_EVENT_DAILY_LIMIT_BYPASS = "daily_limit_bypass"
        private const val INSTAGRAM_REELS_CONTAINER_VIEW_ID =
            "com.instagram.android:id/clips_video_container"
        private const val INSTAGRAM_REELS_ROOT_LAYOUT_VIEW_ID =
            "com.instagram.android:id/root_clips_layout"
        private const val INSTAGRAM_REELS_AUTHOR_USERNAME_VIEW_ID =
            "com.instagram.android:id/clips_author_username"
        private const val INSTAGRAM_REELS_LIKE_COUNT_VIEW_ID =
            "com.instagram.android:id/like_count"
        private const val INSTAGRAM_EXPLORE_ACTION_BAR_VIEW_ID =
            "com.instagram.android:id/explore_action_bar"
        private const val INSTAGRAM_EXPLORE_RECYCLER_VIEW_ID =
            "com.instagram.android:id/recycler_view"
        private const val INSTAGRAM_EXPLORE_REFRESHABLE_CONTAINER_VIEW_ID =
            "com.instagram.android:id/refreshable_container"
        private val instagramNotExploreViewIds = listOf(
            "com.instagram.android:id/reel_item_toolbar_container",
            "com.instagram.android:id/inbox_refreshable_thread_list_recyclerview",
            "com.instagram.android:id/profile_action_bar",
        )
        private val instagramDmThreadViewIds = listOf(
            "com.instagram.android:id/direct_thread_header",
            "com.instagram.android:id/reply_bar_edittext",
        )
        private const val SNAPCHAT_SPOTLIGHT_CONTAINER_VIEW_ID =
            "com.snapchat.android:id/spotlight_container"
        private const val YOUTUBE_SHORTS_CONTAINER_VIEW_ID_SUFFIX =
            "id/reel_player_underlay"
        private const val PROMPT_DEBUG_TAG = "TempusPromptOverlay"
        private const val BLOCK_RETRY_COUNT = 6
        private const val BLOCK_RETRY_DELAY_MS = 250L
        private const val PROMPT_SUPPRESSION_MILLIS = 800L
        private const val USAGE_ACCESS_WATCH_INTERVAL_MILLIS = 500L
        private const val INSTAGRAM_REELS_SCAN_DEBOUNCE_MILLIS = 250L
        private const val INSTAGRAM_REELS_DETECTION_CACHE_MILLIS = 1200L
        private const val SNAPCHAT_SPOTLIGHT_SCAN_DEBOUNCE_MILLIS = 250L
        private const val SNAPCHAT_SPOTLIGHT_DETECTION_CACHE_MILLIS = 1200L
        private const val YOUTUBE_SHORTS_SCAN_DEBOUNCE_MILLIS = 250L
        private const val YOUTUBE_SHORTS_DETECTION_CACHE_MILLIS = 1200L
        private const val INSTAGRAM_EXPLORE_OVERLAY_FLAGS =
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
        private const val INSTAGRAM_EXPLORE_RECT_TOLERANCE_PX = 12
        private const val INSTAGRAM_EXPLORE_REVALIDATION_MILLIS = 1500L
        private const val INSTAGRAM_EXPLORE_RETRY_MILLIS = 700L
        private const val INSTAGRAM_EXPLORE_SHOW_CONFIRM_MILLIS = 250L
        private const val INSTAGRAM_EXPLORE_MISS_GRACE_MILLIS = 1500L
        private const val INSTAGRAM_EXPLORE_MISS_THRESHOLD = 2
        private const val INSTAGRAM_EXPLORE_POSITIVE_HIT_THRESHOLD = 1
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

        @Volatile
        private var promptActive = false

        @Volatile
        private var activeService: AppGuardAccessibilityService? = null

        @Volatile
        private var instagramAllowedUntilMillis = 0L

        @Volatile
        private var youTubeAllowedUntilMillis = 0L

        @Volatile
        private var snapchatAllowedUntilMillis = 0L

        @Volatile
        private var promptSuppressedUntilMillis = 0L

        private val websiteAllowedUntilMillisByDomain =
            ConcurrentHashMap<String, Long>()

        private val pauseOnOpenAllowedUntilMillisByPackage =
            ConcurrentHashMap<String, Long>()

        private val dailyLimitAllowedUntilMillisByPackage =
            ConcurrentHashMap<String, Long>()

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

        fun openWebsiteRedirectAfterPrompt(url: String) {
            promptSuppressedUntilMillis = System.currentTimeMillis() + PROMPT_SUPPRESSION_MILLIS
            activeService?.enforcementHandler?.postDelayed(
                {
                    val service = activeService ?: return@postDelayed
                    runCatching {
                        service.startActivity(
                            Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            },
                        )
                    }.onFailure {
                        Log.e(PROMPT_DEBUG_TAG, "Failed to open redirect url=$url", it)
                    }
                },
                150L,
            )
        }

        fun closePauseOnOpenTarget() {
            promptSuppressedUntilMillis = System.currentTimeMillis() + PROMPT_SUPPRESSION_MILLIS
            activeService?.enforcementHandler?.postDelayed(
                {
                    activeService?.goHome()
                },
                150L,
            )
        }

        fun allowTargetForMinutes(target: String, minutes: Int) {
            val startMillis = System.currentTimeMillis()
            val allowedUntil = startMillis + minutes * 60 * 1000L
            val normalizedTarget = target.lowercase()
            when (normalizedTarget) {
                TARGET_YOUTUBE -> {
                    youTubeAllowedUntilMillis = allowedUntil
                }
                TARGET_SNAPCHAT -> {
                    snapchatAllowedUntilMillis = allowedUntil
                }
                else -> {
                    instagramAllowedUntilMillis = allowedUntil
                }
            }
            if (
                normalizedTarget == TARGET_INSTAGRAM ||
                    normalizedTarget == TARGET_SNAPCHAT ||
                    normalizedTarget == TARGET_YOUTUBE
            ) {
                activeService?.recordStatsEvent(
                    eventType = STATS_EVENT_SHORT_FORM_BYPASS,
                    packageName = activeService?.lastForegroundPackage,
                    target = normalizedTarget,
                    metadata = JSONObject().apply {
                        put("minutes", minutes)
                    },
                )
                activeService?.recordShortFormBypassWindow(
                    target = normalizedTarget,
                    startMillis = startMillis,
                    endMillis = allowedUntil,
                )
            }
            activeService?.dismissPromptOverlay() ?: run {
                promptActive = false
            }
        }

        fun allowWebsiteForMinutes(domain: String?, minutes: Int) {
            val normalizedDomain = domain
                ?.let(WebsiteBlockingSupport::normalizeObservedInput)
                ?.takeIf { it.isNotBlank() }
                ?: return
            if (minutes <= 0) return

            val allowedUntil = System.currentTimeMillis() + minutes * 60L * 1000L
            websiteAllowedUntilMillisByDomain[normalizedDomain] = allowedUntil
            promptSuppressedUntilMillis = System.currentTimeMillis() + PROMPT_SUPPRESSION_MILLIS
            activeService?.recordStatsEvent(
                eventType = STATS_EVENT_WEBSITE_BYPASS,
                packageName = activeService?.lastForegroundPackage,
                target = TARGET_WEBSITE,
                metadata = JSONObject().apply {
                    put("domain", normalizedDomain)
                    put("minutes", minutes)
                },
            )
            activeService?.dismissPromptOverlay() ?: run {
                promptActive = false
            }
        }

        fun allowPauseOnOpen(packageName: String?, minutes: Int) {
            if (packageName.isNullOrBlank() || minutes <= 0) return
            activeService?.recordStatsEvent(
                eventType = STATS_EVENT_PAUSE_ON_OPEN_BYPASS,
                packageName = packageName,
                target = packageName,
                metadata = JSONObject().apply {
                    put("minutes", minutes)
                },
            )
            pauseOnOpenAllowedUntilMillisByPackage[packageName] =
                System.currentTimeMillis() + minutes * 60L * 1000L
            promptSuppressedUntilMillis = System.currentTimeMillis() + PROMPT_SUPPRESSION_MILLIS
            activeService?.dismissPromptOverlay() ?: run {
                promptActive = false
            }
        }

        fun closeDailyLimitTarget() {
            promptSuppressedUntilMillis = System.currentTimeMillis() + PROMPT_SUPPRESSION_MILLIS
            activeService?.enforcementHandler?.postDelayed(
                {
                    activeService?.goHome()
                },
                150L,
            )
        }

        fun allowDailyLimitForMinutes(packageName: String?, minutes: Int) {
            if (packageName.isNullOrBlank() || minutes <= 0) return
            activeService?.recordStatsEvent(
                eventType = STATS_EVENT_DAILY_LIMIT_BYPASS,
                packageName = packageName,
                target = packageName,
                metadata = JSONObject().apply {
                    put("minutes", minutes)
                },
            )
            dailyLimitAllowedUntilMillisByPackage[packageName] =
                System.currentTimeMillis() + minutes * 60L * 1000L
            promptSuppressedUntilMillis = System.currentTimeMillis() + PROMPT_SUPPRESSION_MILLIS
            activeService?.dismissPromptOverlay() ?: run {
                promptActive = false
            }
        }

        fun beginUsageAccessEnableWatch() {
            activeService?.startUsageAccessEnableWatcherIfNeeded()
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

    private fun customTrackedAppPauseOnOpenSettingKey(packageName: String): String {
        return "custom_app_pause_on_open_" + packageName.replace(Regex("[^A-Za-z0-9]+"), "_")
    }

    private fun handleAccessibilityEnabledReturn() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val awaitingEnable = prefs.getBoolean(AWAITING_ACCESSIBILITY_ENABLE_PREF_KEY, false)
        if (!awaitingEnable) return

        prefs.edit()
            .putBoolean(AWAITING_ACCESSIBILITY_ENABLE_PREF_KEY, false)
            .putBoolean(ACCESSIBILITY_ENABLED_SUCCESS_PREF_KEY, true)
            .apply()

        relaunchAppToForeground()
    }

    private fun startUsageAccessEnableWatcherIfNeeded() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val awaitingEnable = prefs.getBoolean(AWAITING_USAGE_ACCESS_ENABLE_PREF_KEY, false)
        if (!awaitingEnable) return
        enforcementHandler.removeCallbacks(usageAccessEnableWatcher)
        enforcementHandler.post(usageAccessEnableWatcher)
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

        runCatching {
            startActivity(intent)
        }.onFailure {
            Log.e(PROMPT_DEBUG_TAG, "Failed to relaunch app after permission enable", it)
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

private data class WebsiteContext(
    val packageName: String,
    val observedDomain: String,
    val matchedBlockedDomain: String?,
)

private data class CustomTrackedAppConfig(
    val appName: String,
    val packageName: String,
)

