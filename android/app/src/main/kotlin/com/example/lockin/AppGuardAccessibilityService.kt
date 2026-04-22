package com.example.lockin

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent

class AppGuardAccessibilityService : AccessibilityService() {
    private var lastForegroundPackage: String? = null

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val eventType = event?.eventType ?: return
        if (
            eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            eventType != AccessibilityEvent.TYPE_VIEW_CLICKED
        ) {
            return
        }

        val packageName = event.packageName?.toString() ?: return

        if (packageName != lastForegroundPackage) {
            lastForegroundPackage = packageName
        }

        if (packageName != INSTAGRAM_PACKAGE_NAME) return
        if (promptActive || isInstagramAllowed()) return
        if (eventType != AccessibilityEvent.TYPE_VIEW_CLICKED) return
        if (!isReelsClick(event)) return

        promptActive = true
        startActivity(
            Intent(this, ConfirmInstagramActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                addFlags(Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
            },
        )
    }

    override fun onInterrupt() = Unit

    private fun isInstagramAllowed(): Boolean {
        return System.currentTimeMillis() < instagramAllowedUntilMillis
    }

    private fun isReelsClick(event: AccessibilityEvent): Boolean {
        val clickedLabel = buildString {
            event.text.forEach { append(' ').append(it) }
            append(' ').append(event.contentDescription?.toString().orEmpty())
        }.trim()

        if (clickedLabel.equals("reels", ignoreCase = true)) return true

        return REELS_CLICK_CLUES.any { clue ->
            clickedLabel.contains(clue, ignoreCase = true)
        }
    }

    companion object {
        const val INSTAGRAM_PACKAGE_NAME = "com.instagram.android"
        private val REELS_CLICK_CLUES = listOf(
            "reels tab",
            "reels button",
            "open reels",
        )

        @Volatile
        private var promptActive = false

        @Volatile
        private var instagramAllowedUntilMillis = 0L

        fun dismissPrompt() {
            promptActive = false
        }

        fun allowInstagramForMinutes(minutes: Int) {
            instagramAllowedUntilMillis = System.currentTimeMillis() + minutes * 60 * 1000L
            promptActive = false
        }
    }
}
