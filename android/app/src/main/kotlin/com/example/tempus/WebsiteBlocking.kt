package com.prestige.tempus

import android.view.accessibility.AccessibilityNodeInfo
import android.webkit.URLUtil
import java.net.URI
import java.util.Locale

internal data class BrowserUrlConfig(
    val packageName: String,
    val urlViewIds: List<String>,
    val textTransform: (String) -> String = { value -> value },
)

internal data class BlockedWebsiteRule(
    val domain: String,
    val isEnabled: Boolean,
)

internal data class BrowserObservation(
    val domain: String,
    val isEditingAddressBar: Boolean,
)

internal object WebsiteBlockingSupport {
    private val domainRegex = Regex(
        pattern = "(?i)\\b((?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\\.)+(?:[a-z]{2,}|xn--[a-z0-9-]{2,}))\\b",
    )

    private val browserConfigs = listOf(
        BrowserUrlConfig(
            packageName = "com.android.chrome",
            urlViewIds = listOf("com.android.chrome:id/url_bar"),
        ),
        BrowserUrlConfig(
            packageName = "com.google.android.apps.searchlite",
            urlViewIds = listOf("com.google.android.apps.searchlite:id/webx_url_bar"),
        ),
        BrowserUrlConfig(
            packageName = "com.brave.browser",
            urlViewIds = listOf("com.brave.browser:id/url_bar"),
        ),
        BrowserUrlConfig(
            packageName = "com.brave.browser_beta",
            urlViewIds = listOf("com.brave.browser_beta:id/url_bar"),
        ),
        BrowserUrlConfig(
            packageName = "com.brave.browser_nightly",
            urlViewIds = listOf("com.brave.browser_nightly:id/url_bar"),
        ),
        BrowserUrlConfig(
            packageName = "com.microsoft.emmx",
            urlViewIds = listOf("com.microsoft.emmx:id/url_bar"),
        ),
        BrowserUrlConfig(
            packageName = "org.mozilla.firefox",
            urlViewIds = listOf("org.mozilla.firefox:id/mozac_browser_toolbar_url_view"),
        ),
        BrowserUrlConfig(
            packageName = "org.mozilla.firefox_beta",
            urlViewIds = listOf("org.mozilla.firefox_beta:id/mozac_browser_toolbar_url_view"),
        ),
        BrowserUrlConfig(
            packageName = "org.mozilla.fenix",
            urlViewIds = listOf("org.mozilla.fenix:id/mozac_browser_toolbar_url_view"),
        ),
        BrowserUrlConfig(
            packageName = "org.mozilla.focus",
            urlViewIds = listOf("org.mozilla.focus:id/mozac_browser_toolbar_url_view"),
        ),
        BrowserUrlConfig(
            packageName = "org.mozilla.klar",
            urlViewIds = listOf("org.mozilla.klar:id/mozac_browser_toolbar_url_view"),
        ),
        BrowserUrlConfig(
            packageName = "com.sec.android.app.sbrowser",
            urlViewIds = listOf(
                "com.sec.android.app.sbrowser:id/location_bar_edit_text",
                "com.sec.android.app.sbrowser:id/location_bar",
            ),
        ),
        BrowserUrlConfig(
            packageName = AppGuardAccessibilityService.INSTAGRAM_PACKAGE_NAME,
            urlViewIds = listOf("com.instagram.android:id/ig_browser_text_subtitle"),
            textTransform = { value -> value.removeSuffix(".") },
        ),
    )

    private val browserConfigByPackage = browserConfigs.associateBy { config -> config.packageName }

    fun isSupportedBrowserPackage(packageName: String): Boolean {
        return browserConfigByPackage.containsKey(packageName)
    }

    fun extractObservedDomain(
        rootNode: AccessibilityNodeInfo?,
        packageName: String,
        subtreeTextExtractor: (AccessibilityNodeInfo) -> String,
    ): BrowserObservation? {
        val config = browserConfigByPackage[packageName] ?: return null
        val root = rootNode ?: return null

        for (viewId in config.urlViewIds) {
            val nodes = root.findAccessibilityNodeInfosByViewId(viewId) ?: continue
            for (node in nodes) {
                if (node == null || !node.isVisibleToUser) continue
                val rawText = node.text?.toString()
                    ?: node.contentDescription?.toString()
                    ?: subtreeTextExtractor(node)
                val transformed = config.textTransform(rawText).trim()
                val normalized = normalizeObservedInput(transformed)
                if (normalized.isNotEmpty()) {
                    return BrowserObservation(
                        domain = normalized,
                        isEditingAddressBar = isEditingAddressBar(node),
                    )
                }
            }
        }

        return null
    }

    private fun isEditingAddressBar(node: AccessibilityNodeInfo): Boolean {
        return node.isFocused || node.isAccessibilityFocused
    }

    fun normalizeObservedInput(input: String): String {
        val trimmed = input.trim()
        if (trimmed.isEmpty()) return ""

        val hostCandidate = runCatching {
            if (URLUtil.isValidUrl(trimmed)) {
                URI(trimmed).host.orEmpty()
            } else {
                domainRegex.find(trimmed)?.groupValues?.getOrNull(1).orEmpty()
            }
        }.getOrElse {
            domainRegex.find(trimmed)?.groupValues?.getOrNull(1).orEmpty()
        }

        if (hostCandidate.isBlank()) return ""

        return hostCandidate
            .substringBefore('/')
            .trim()
            .trimEnd('.')
            .lowercase(Locale.US)
            .removePrefix("www.")
    }

    fun findMatchingBlockedDomain(
        blockedDomains: Collection<String>,
        observedDomain: String,
    ): String? {
        val normalizedObserved = normalizeObservedInput(observedDomain)
        if (normalizedObserved.isEmpty()) return null

        return blockedDomains.firstOrNull { blockedDomain ->
            domainMatches(normalizedObserved, blockedDomain)
        }
    }

    fun domainMatches(
        candidateDomain: String,
        blockedDomain: String,
    ): Boolean {
        val candidate = normalizeObservedInput(candidateDomain)
        val blocked = normalizeObservedInput(blockedDomain)
        if (candidate.isEmpty() || blocked.isEmpty()) return false
        return candidate.equals(blocked, ignoreCase = true) ||
            candidate.endsWith(".$blocked", ignoreCase = true)
    }
}
