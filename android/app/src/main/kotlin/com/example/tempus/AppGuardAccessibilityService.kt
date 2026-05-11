package com.prestige.tempus

import android.accessibilityservice.AccessibilityService
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.util.Calendar
import java.util.concurrent.ConcurrentHashMap
import org.json.JSONArray

class AppGuardAccessibilityService : AccessibilityService() {
    private var lastForegroundPackage: String? = null
    private val enforcementHandler = Handler(Looper.getMainLooper())
    private var promptTarget: String? = null
    private var promptPackageName: String? = null
    private var lastInstagramReelsScanAtMillis = 0L
    private var instagramReelsDetectedUntilMillis = 0L
    private var lastYouTubeShortsScanAtMillis = 0L
    private var youTubeShortsDetectedUntilMillis = 0L
    private val lastVisibleBlockedWebsiteByPackage = mutableMapOf<String, String>()

    override fun onServiceConnected() {
        activeService = this
        handleAccessibilityEnabledReturn()
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
        val packageChanged = previousPackageName != packageName
        if (previousPackageName != null && previousPackageName != packageName) {
            lastVisibleBlockedWebsiteByPackage.remove(previousPackageName)
        }
        if (packageName != lastForegroundPackage) {
            lastForegroundPackage = packageName
            if (packageName != INSTAGRAM_PACKAGE_NAME) {
                clearInstagramReelsDetectionCache()
            }
            if (!isYouTubePackage(packageName)) {
                clearYouTubeShortsDetectionCache()
            }
            if (
                promptActive &&
                promptTarget != null &&
                shouldDismissPromptForPackage(packageName, promptPackageName)
            ) {
                dismissPromptOverlay()
            }
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

        val blockedWebsiteDomain = findBlockedWebsiteDomain(packageName)
        if (blockedWebsiteDomain == null) {
            lastVisibleBlockedWebsiteByPackage.remove(packageName)
        } else {
            lastVisibleBlockedWebsiteByPackage[packageName] = blockedWebsiteDomain
            if (
                !promptActive &&
                !isPackageTemporarilyAllowed(packageName) &&
                !isBlockedWebsiteTemporarilyAllowed(packageName, blockedWebsiteDomain)
            ) {
                openWebsitePrompt(packageName, blockedWebsiteDomain)
                return
            }
        }

        if (promptActive || isPackageTemporarilyAllowed(packageName)) return
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
        }
    }

    override fun onInterrupt() = Unit

    override fun onDestroy() {
        if (activeService === this) {
            activeService = null
        }
        enforcementHandler.removeCallbacksAndMessages(null)
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

    private fun isInstagramReelsDmsAllowed(): Boolean {
        return getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(INSTAGRAM_REELS_DMS_SETTING_KEY, false)
    }

    private fun isYouTubeShortsBlockingEnabled(): Boolean {
        return getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(YOUTUBE_SHORTS_SETTING_KEY, false)
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
        showPromptActivity(
            target = TARGET_INSTAGRAM,
            sourcePackageName = lastForegroundPackage,
            appLabel = "Instagram",
        )
    }

    private fun openYouTubePrompt() {
        promptActive = true
        pauseYouTubeShortsPlayback(lastForegroundPackage)
        showPromptActivity(
            target = TARGET_YOUTUBE,
            sourcePackageName = lastForegroundPackage,
            appLabel = "YouTube",
        )
    }

    private fun openPauseOnOpenPrompt(packageName: String) {
        promptActive = true
        showPauseOnOpenActivity(
            sourcePackageName = packageName,
            appLabel = getTrackedAppPromptLabel(packageName),
        )
    }

    private fun openWebsitePrompt(packageName: String, domain: String) {
        promptActive = true
        showWebsiteBlockActivity(
            sourcePackageName = packageName,
            domain = domain,
        )
    }

    private fun openDailyLimitPrompt(packageName: String) {
        promptActive = true
        showDailyLimitReachedActivity(
            sourcePackageName = packageName,
            appLabel = getTrackedAppPromptLabel(packageName),
        )
    }

    private fun showPromptActivity(
        target: String,
        sourcePackageName: String?,
        appLabel: String,
    ) {
        enforcementHandler.post {
            dismissPromptState()
            promptTarget = target
            promptPackageName = sourcePackageName
            val intent = Intent(this, ConfirmBlockerActivity::class.java).apply {
                putExtra(ConfirmBlockerActivity.EXTRA_TARGET, target)
                putExtra(ConfirmBlockerActivity.EXTRA_APP_LABEL, appLabel)
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
            dismissPromptState()
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

    private fun showWebsiteBlockActivity(
        sourcePackageName: String,
        domain: String,
    ) {
        enforcementHandler.post {
            dismissPromptState()
            promptTarget = TARGET_WEBSITE
            promptPackageName = sourcePackageName
            val intent = Intent(this, WebsiteBlockActivity::class.java).apply {
                putExtra(WebsiteBlockActivity.EXTRA_SOURCE_PACKAGE_NAME, sourcePackageName)
                putExtra(WebsiteBlockActivity.EXTRA_DOMAIN, domain)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            runCatching {
                startActivity(intent)
                Log.d(PROMPT_DEBUG_TAG, "Showing website block activity for domain=$domain")
            }.onFailure {
                Log.e(PROMPT_DEBUG_TAG, "Failed to show website block activity", it)
                dismissPromptState()
            }
        }
    }

    private fun showDailyLimitReachedActivity(
        sourcePackageName: String,
        appLabel: String,
    ) {
        enforcementHandler.post {
            dismissPromptState()
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

    private fun isBlockedWebsiteTemporarilyAllowed(
        packageName: String,
        domain: String,
    ): Boolean {
        val allowedWebsite = temporarilyAllowedWebsiteDomainsByPackage[packageName] ?: return false
        val now = System.currentTimeMillis()
        if (now >= allowedWebsite.allowedUntilMillis) {
            temporarilyAllowedWebsiteDomainsByPackage.remove(packageName)
            return false
        }
        return allowedWebsite.domain.equals(domain, ignoreCase = true)
    }

    private fun findBlockedWebsiteDomain(packageName: String): String? {
        val urlFieldIds = browserUrlFieldIdsByPackage[packageName] ?: return null
        val blockedDomains = getBlockedWebsiteDomains()
        if (blockedDomains.isEmpty()) return null

        val rootNode = rootInActiveWindow ?: return null
        val visibleUrlText = extractBrowserUrlText(rootNode, urlFieldIds)
            ?.replace(Regex("\\s+"), " ")
            ?.trim()
            ?.lowercase()
            ?: return null
        if (visibleUrlText.isBlank()) return null

        return blockedDomains.firstOrNull { domain ->
            containsBlockedDomain(visibleUrlText, domain)
        }
    }

    private fun extractBrowserUrlText(
        rootNode: AccessibilityNodeInfo,
        viewIds: List<String>,
    ): String? {
        viewIds.forEach { viewId ->
            val matchingNodes = runCatching {
                rootNode.findAccessibilityNodeInfosByViewId(viewId)
            }.getOrNull().orEmpty()
            matchingNodes.firstOrNull(::isUsableBrowserUrlNode)?.let { node ->
                return node.text?.toString()
                    ?.takeIf { it.isNotBlank() }
                    ?: node.contentDescription?.toString()?.takeIf { it.isNotBlank() }
            }
        }
        return null
    }

    private fun isUsableBrowserUrlNode(node: AccessibilityNodeInfo): Boolean {
        if (!node.isVisibleToUser) return false
        if (node.isContentInvalid) return false
        val text = node.text?.toString()?.trim().orEmpty()
        val contentDescription = node.contentDescription?.toString()?.trim().orEmpty()
        return text.isNotBlank() || contentDescription.isNotBlank()
    }

    private fun containsBlockedDomain(text: String, domain: String): Boolean {
        val normalizedDomain = normalizeDomain(domain)
        if (normalizedDomain.isBlank()) return false
        val escapedDomain = Regex.escape(normalizedDomain)
        val pattern = Regex(
            """(^|[^a-z0-9.-])(?:https?://)?(?:www\.)?$escapedDomain(?=$|[/:?\s])""",
        )
        return pattern.containsMatchIn(text)
    }

    private fun normalizeDomain(input: String): String {
        return input.trim()
            .lowercase()
            .replaceFirst(Regex("^https?://"), "")
            .replaceFirst(Regex("^www\\."), "")
            .replace(Regex("/.*$"), "")
            .trim()
    }

    private fun getBlockedWebsiteDomains(): List<String> {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val serialized = prefs.getString(BLOCKED_WEBSITES_PREF_KEY, null) ?: return emptyList()
        val blockedWebsiteArray = JSONArray(serialized)
        return List(blockedWebsiteArray.length()) { index ->
            normalizeDomain(blockedWebsiteArray.getJSONObject(index).optString("domain"))
        }.filter { domain ->
            domain.isNotBlank()
        }
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
                if (isInstagramReelsDmsAllowed() && isInstagramDmThreadContext()) {
                    return false
                }
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

    private fun isYouTubePackage(packageName: String): Boolean {
        return packageName == YOUTUBE_PACKAGE_NAME ||
            packageName.startsWith(YOUTUBE_REVANCED_PACKAGE_PREFIX)
    }

    companion object {
        const val PREFS_NAME = "tempus_app_guard"
        const val CUSTOM_TRACKED_APPS_PREF_KEY = "custom_tracked_apps"
        const val BLOCKED_WEBSITES_PREF_KEY = "blocked_websites"
        const val TEN_SECOND_LIMIT_VALUE = -10
        const val AWAITING_ACCESSIBILITY_ENABLE_PREF_KEY = "awaiting_accessibility_enable"
        const val ACCESSIBILITY_ENABLED_SUCCESS_PREF_KEY = "accessibility_enabled_success"
        const val INSTAGRAM_PACKAGE_NAME = "com.instagram.android"
        const val YOUTUBE_PACKAGE_NAME = "com.google.android.youtube"
        const val YOUTUBE_REVANCED_PACKAGE_PREFIX = "app.revanced.android.youtube"
        const val INSTAGRAM_REELS_SETTING_KEY = "instagram_reels"
        const val INSTAGRAM_REELS_DMS_SETTING_KEY = "instagram_reels_dms"
        const val INSTAGRAM_PAUSE_ON_OPEN_SETTING_KEY = "instagram_pause_on_open"
        const val INSTAGRAM_STORIES_SETTING_KEY = "instagram_explore"
        const val YOUTUBE_PAUSE_ON_OPEN_SETTING_KEY = "youtube_pause_on_open"
        const val YOUTUBE_SHORTS_SETTING_KEY = "youtube_shorts"
        const val TARGET_INSTAGRAM = "instagram"
        const val TARGET_YOUTUBE = "youtube"
        const val TARGET_PAUSE_ON_OPEN = "pause_on_open"
        const val TARGET_WEBSITE = "website"
        const val TARGET_DAILY_LIMIT = "daily_limit"
        private const val INSTAGRAM_REELS_CONTAINER_VIEW_ID =
            "com.instagram.android:id/clips_video_container"
        private val instagramDmThreadViewIds = listOf(
            "com.instagram.android:id/direct_thread_header",
            "com.instagram.android:id/reply_bar_edittext",
        )
        private const val YOUTUBE_SHORTS_CONTAINER_VIEW_ID_SUFFIX =
            "id/reel_player_underlay"
        private const val PROMPT_DEBUG_TAG = "TempusPromptOverlay"
        private const val BLOCK_RETRY_COUNT = 6
        private const val BLOCK_RETRY_DELAY_MS = 250L
        private const val PROMPT_SUPPRESSION_MILLIS = 800L
        private const val INSTAGRAM_REELS_SCAN_DEBOUNCE_MILLIS = 250L
        private const val INSTAGRAM_REELS_DETECTION_CACHE_MILLIS = 1200L
        private const val YOUTUBE_SHORTS_SCAN_DEBOUNCE_MILLIS = 250L
        private const val YOUTUBE_SHORTS_DETECTION_CACHE_MILLIS = 1200L
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

        private val pauseOnOpenAllowedUntilMillisByPackage =
            ConcurrentHashMap<String, Long>()

        private val dailyLimitAllowedUntilMillisByPackage =
            ConcurrentHashMap<String, Long>()

        private val temporarilyAllowedWebsiteDomainsByPackage =
            ConcurrentHashMap<String, AllowedWebsite>()

        private val browserUrlFieldIdsByPackage = mapOf(
            "com.android.chrome" to listOf(
                "com.android.chrome:id/url_bar",
            ),
            "org.chromium.chrome" to listOf(
                "org.chromium.chrome:id/url_bar",
            ),
            "com.chrome.beta" to listOf(
                "com.chrome.beta:id/url_bar",
            ),
            "com.chrome.dev" to listOf(
                "com.chrome.dev:id/url_bar",
            ),
            "com.google.android.apps.chrome" to listOf(
                "com.google.android.apps.chrome:id/url_bar",
            ),
            "com.sec.android.app.sbrowser" to listOf(
                "com.sec.android.app.sbrowser:id/location_bar_edit_text",
                "com.sec.android.app.sbrowser:id/custom_tab_toolbar_url_bar_text",
            ),
            "org.mozilla.focus" to listOf(
                "org.mozilla.focus:id/mozac_browser_toolbar_url_view",
            ),
            "org.mozilla.firefox" to listOf(
                "org.mozilla.firefox:id/mozac_browser_toolbar_url_view",
            ),
            "com.brave.browser" to listOf(
                "com.brave.browser:id/url_bar",
            ),
            "com.microsoft.emmx" to listOf(
                "com.microsoft.emmx:id/url_bar",
            ),
            "com.opera.browser" to listOf(
                "com.opera.browser:id/url_field",
            ),
            "com.opera.mini.native" to listOf(
                "com.opera.mini.native:id/url_field",
            ),
            "com.vivaldi.browser" to listOf(
                "com.vivaldi.browser:id/url_bar",
            ),
            "com.kiwibrowser.browser" to listOf(
                "com.kiwibrowser.browser:id/url_bar",
            ),
            "com.instagram.android" to listOf(
                "com.instagram.android:id/ig_browser_text_subtitle",
            ),
        )

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

        fun closeBlockedWebsiteTarget() {
            promptSuppressedUntilMillis = System.currentTimeMillis() + PROMPT_SUPPRESSION_MILLIS
            activeService?.enforcementHandler?.postDelayed(
                {
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com")).apply {
                        addCategory(Intent.CATEGORY_BROWSABLE)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    runCatching {
                        activeService?.startActivity(intent)
                    }.onFailure {
                        activeService?.goHome()
                    }
                },
                150L,
            )
        }

        fun allowWebsiteForMinutes(packageName: String?, domain: String?, minutes: Int) {
            if (packageName.isNullOrBlank() || domain.isNullOrBlank()) return
            temporarilyAllowedWebsiteDomainsByPackage[packageName] = AllowedWebsite(
                domain = domain.trim().lowercase(),
                allowedUntilMillis = System.currentTimeMillis() + minutes * 60 * 1000L,
            )
            promptSuppressedUntilMillis = System.currentTimeMillis() + PROMPT_SUPPRESSION_MILLIS
            activeService?.dismissPromptOverlay() ?: run {
                promptActive = false
            }
        }

        fun allowPauseOnOpen(packageName: String?, minutes: Int) {
            if (packageName.isNullOrBlank() || minutes <= 0) return
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
            dailyLimitAllowedUntilMillisByPackage[packageName] =
                System.currentTimeMillis() + minutes * 60L * 1000L
            promptSuppressedUntilMillis = System.currentTimeMillis() + PROMPT_SUPPRESSION_MILLIS
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

        val intent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        } ?: return

        runCatching {
            startActivity(intent)
        }.onFailure {
            Log.e(PROMPT_DEBUG_TAG, "Failed to relaunch app after accessibility enable", it)
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

private data class CustomTrackedAppConfig(
    val appName: String,
    val packageName: String,
)

private data class AllowedWebsite(
    val domain: String,
    val allowedUntilMillis: Long,
)
