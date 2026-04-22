package com.example.lockin

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent

class AppGuardAccessibilityService : AccessibilityService() {
    private var lastForegroundPackage: String? = null

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val packageName = event.packageName?.toString() ?: return

        if (packageName != lastForegroundPackage) {
            lastForegroundPackage = packageName
        }

        if (packageName != INSTAGRAM_PACKAGE_NAME) return
        if (promptActive || isInstagramAllowed()) return

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

    companion object {
        const val INSTAGRAM_PACKAGE_NAME = "com.instagram.android"
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
