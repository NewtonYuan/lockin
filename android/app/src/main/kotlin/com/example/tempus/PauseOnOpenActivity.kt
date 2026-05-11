package com.prestige.tempus

import android.app.Activity
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.os.Bundle
import android.text.SpannableString
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

class PauseOnOpenActivity : Activity() {
    private val minuteOptions = intArrayOf(1, 3, 5, 10, 15, 30, 45, 60)

    private val sourcePackageName: String?
        get() = intent?.getStringExtra(EXTRA_SOURCE_PACKAGE_NAME)

    private val appLabel: String
        get() = intent?.getStringExtra(EXTRA_APP_LABEL)
            ?.takeIf { it.isNotBlank() }
            ?: "this app"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setBackgroundDrawableResource(android.R.color.transparent)
        setPromptContent(createPromptView())
        overridePendingTransition(R.anim.prompt_fade_in, R.anim.prompt_fade_out)
    }

    @Deprecated("Back is intentionally disabled for this prompt")
    override fun onBackPressed() {
        // Intentionally no-op. Exit paths should go through the prompt actions.
    }

    private fun createPromptView(): FrameLayout {
        return promptFrame().apply {
            addView(promptPanel().apply {
                addView(
                    logoView(),
                    logoLayoutParams(),
                )

                addView(
                    TextView(context).apply {
                        text = pauseTitle(appLabel)
                        setTextColor(Color.rgb(17, 24, 39))
                        textSize = 30f
                        gravity = Gravity.CENTER
                        setTypeface(typeface, Typeface.BOLD)
                    },
                    matchWidthLayoutParams(),
                )

                addView(
                    Button(context).apply {
                        text = "No, not really"
                        setTextColor(Color.WHITE)
                        background = prominentRippleBackground()
                        setAllCaps(false)
                        textSize = 16f
                        setTypeface(typeface, Typeface.BOLD)
                        minHeight = dp(48)
                        setPadding(dp(16), 0, dp(16), 0)
                        setOnClickListener {
                            AppGuardAccessibilityService.dismissPrompt()
                            AppGuardAccessibilityService.closePauseOnOpenTarget()
                            finish()
                        }
                    },
                    buttonLayoutParams(topMargin = dp(40)),
                )

                addView(
                    Button(context).apply {
                        text = "I do"
                        setTextColor(BRAND)
                        textSize = 16f
                        gravity = Gravity.CENTER
                        setTypeface(typeface, Typeface.BOLD)
                        background = outlinedRippleBackground()
                        minHeight = dp(48)
                        setAllCaps(false)
                        setPadding(dp(16), 0, dp(16), 0)
                        setOnClickListener {
                            setPromptContent(createMinutesView())
                        }
                    },
                    buttonLayoutParams(topMargin = dp(10)),
                )

                addView(
                    TextView(context).apply {
                        visibility = View.GONE
                    },
                    LinearLayout.LayoutParams(0, 0),
                )
            })
        }
    }

    private fun createMinutesView(): FrameLayout {
        val subtitleView = TextView(this).apply {
            setTextColor(Color.rgb(95, 107, 122))
            textSize = 12f
            gravity = Gravity.CENTER
        }
        val dailyLimitMinutes = resolveDailyLimitMinutes(sourcePackageName)
        val usedTodayMinutes = getTodayForegroundMinutes(sourcePackageName)
        fun updateSubtitle(selectedMinutes: Int) {
            subtitleView.text =
                if (dailyLimitMinutes == null || dailyLimitMinutes <= 0) {
                    "$usedTodayMinutes ${if (usedTodayMinutes == 1L) "minute" else "minutes"} on $appLabel today"
                } else {
                    val remainingMinutes = (dailyLimitMinutes - usedTodayMinutes).coerceAtLeast(0)
                    "$remainingMinutes ${if (remainingMinutes == 1L) "minute" else "minutes"} left until your daily limit"
                }
        }
        val picker = DurationWheelPicker(
            context = this,
            values = minuteOptions,
            initialValue = 1,
            labelBuilder = ::durationLabel,
            onSelectionChanged = ::updateSubtitle,
        )
        updateSubtitle(picker.selectedValue())

        return promptFrame().apply {
            addView(promptPanel().apply {
                addView(
                    logoView(),
                    logoLayoutParams(),
                )

                addView(
                    TextView(context).apply {
                        text = "For how long?"
                        setTextColor(Color.rgb(17, 24, 39))
                        textSize = 34f
                        gravity = Gravity.CENTER
                        setTypeface(typeface, Typeface.BOLD)
                    },
                    matchWidthLayoutParams(),
                )

                addView(
                    subtitleView,
                    LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                    ).apply {
                        topMargin = dp(8)
                    },
                )

                addView(
                    FrameLayout(context).apply {
                        addView(
                            picker.view,
                            FrameLayout.LayoutParams(
                                ViewGroup.LayoutParams.MATCH_PARENT,
                                picker.heightPx,
                                Gravity.CENTER,
                            ),
                        )
                    },
                    LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                    ).apply {
                        topMargin = dp(20)
                        bottomMargin = dp(20)
                    },
                )

                addView(
                    Button(context).apply {
                        text = "Continue"
                        setTextColor(Color.WHITE)
                        background = prominentRippleBackground()
                        setAllCaps(false)
                        textSize = 18f
                        setTypeface(typeface, Typeface.BOLD)
                        minHeight = dp(48)
                        setPadding(dp(16), 0, dp(16), 0)
                        setOnClickListener {
                            AppGuardAccessibilityService.allowPauseOnOpen(
                                sourcePackageName,
                                picker.selectedValue(),
                            )
                            finish()
                        }
                    },
                    buttonLayoutParams(),
                )

                addView(
                    Button(context).apply {
                        text = "Nevermind"
                        setTextColor(BRAND)
                        textSize = 16f
                        gravity = Gravity.CENTER
                        setTypeface(typeface, Typeface.BOLD)
                        background = outlinedRippleBackground()
                        minHeight = dp(48)
                        setAllCaps(false)
                        setPadding(dp(16), 0, dp(16), 0)
                        setOnClickListener {
                            AppGuardAccessibilityService.dismissPrompt()
                            AppGuardAccessibilityService.closePauseOnOpenTarget()
                            finish()
                        }
                    },
                    buttonLayoutParams(topMargin = dp(10)),
                )
            })
        }
    }

    override fun onDestroy() {
        AppGuardAccessibilityService.dismissPrompt()
        super.onDestroy()
    }

    override fun finish() {
        val content = window.decorView.findViewById<ViewGroup>(android.R.id.content)
        val root = content.getChildAt(0) as? ViewGroup
        val panel = root?.findViewWithTag<View>(PROMPT_PANEL_TAG)
        if (root == null || panel == null) {
            super.finish()
            overridePendingTransition(R.anim.prompt_fade_in, R.anim.prompt_fade_out)
            return
        }

        panel.animate()
            .alpha(0f)
            .setDuration(110L)
            .withEndAction {
                super.finish()
                overridePendingTransition(R.anim.prompt_fade_in, R.anim.prompt_fade_out)
            }
            .start()
    }

    private fun setPromptContent(view: View) {
        setContentView(view)
        val panel = (view as? ViewGroup)?.findViewWithTag<View>(PROMPT_PANEL_TAG) ?: view
        panel.alpha = 0f
        panel.animate()
            .alpha(1f)
            .setDuration(140L)
            .start()
    }

    private fun buttonLayoutParams(topMargin: Int = 0): LinearLayout.LayoutParams {
        return LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT,
        ).apply {
            this.topMargin = topMargin
        }
    }

    private fun matchWidthLayoutParams(): LinearLayout.LayoutParams {
        return LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT,
        )
    }

    private fun logoLayoutParams(): LinearLayout.LayoutParams {
        return LinearLayout.LayoutParams(dp(84), dp(84)).apply {
            gravity = Gravity.CENTER_HORIZONTAL
            bottomMargin = dp(12)
        }
    }

    private fun promptFrame(): FrameLayout {
        return FrameLayout(this).apply {
            setBackgroundColor(Color.WHITE)
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
            isClickable = true
            isFocusable = true
        }
    }

    private fun promptPanel(): LinearLayout {
        return LinearLayout(this).apply {
            tag = PROMPT_PANEL_TAG
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(24), dp(48), dp(24), dp(48))
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
                Gravity.CENTER,
            )
        }
    }

    private fun logoView(): ImageView {
        return ImageView(this).apply {
            setImageResource(R.drawable.launch_logo)
            imageTintList = ColorStateList.valueOf(BRAND)
            scaleType = ImageView.ScaleType.FIT_CENTER
        }
    }

    private fun pauseTitle(label: String): CharSequence {
        val title = "Do you need\n$label"
        val spannable = SpannableString(title)
        val needStart = title.indexOf("need")
        val needEnd = needStart + "need".length
        if (needStart >= 0) {
            spannable.setSpan(
                ForegroundColorSpan(BRAND),
                needStart,
                needEnd,
                Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
            )
        }
        return spannable
    }

    private fun durationLabel(minutes: Int): String {
        return when (minutes) {
            1 -> "1 minute"
            60 -> "60 minutes"
            else -> "$minutes minutes"
        }
    }

    private fun resolveDailyLimitMinutes(packageName: String?): Int? {
        if (packageName.isNullOrBlank()) return null
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val settingKey = when {
            packageName == INSTAGRAM_PACKAGE_NAME -> INSTAGRAM_APP_LIMIT_SETTING_KEY
            packageName == YOUTUBE_PACKAGE_NAME -> YOUTUBE_APP_LIMIT_SETTING_KEY
            packageName.startsWith(REVANCED_YOUTUBE_PREFIX) -> YOUTUBE_APP_LIMIT_SETTING_KEY
            else -> customTrackedAppSettingKey(packageName)
        }
        val stored = prefs.getInt(settingKey, 0)
        return stored.takeIf { it > 0 }
    }

    private fun getTodayForegroundMinutes(packageName: String?): Long {
        if (packageName.isNullOrBlank()) return 0L
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val calendar = java.util.Calendar.getInstance()
        val endTime = calendar.timeInMillis
        calendar.set(java.util.Calendar.HOUR_OF_DAY, 0)
        calendar.set(java.util.Calendar.MINUTE, 0)
        calendar.set(java.util.Calendar.SECOND, 0)
        calendar.set(java.util.Calendar.MILLISECOND, 0)
        val startTime = calendar.timeInMillis
        val usageEvents = usageStatsManager.queryEvents(startTime, endTime)
        val event = UsageEvents.Event()
        var activeStart: Long? = null
        var totalMillis = 0L

        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            val eventPackage = event.packageName ?: continue
            if (!matchesPausedAppPackage(packageName, eventPackage)) continue
            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED,
                UsageEvents.Event.MOVE_TO_FOREGROUND,
                -> activeStart = event.timeStamp

                UsageEvents.Event.ACTIVITY_PAUSED,
                UsageEvents.Event.MOVE_TO_BACKGROUND,
                -> {
                    val start = activeStart ?: continue
                    if (event.timeStamp > start) {
                        totalMillis += event.timeStamp - start
                    }
                    activeStart = null
                }
            }
        }

        activeStart?.let { start ->
            if (endTime > start) {
                totalMillis += endTime - start
            }
        }

        return totalMillis / 60000L
    }

    private fun matchesPausedAppPackage(targetPackage: String, eventPackage: String): Boolean {
        return when {
            targetPackage == YOUTUBE_PACKAGE_NAME -> {
                eventPackage == YOUTUBE_PACKAGE_NAME || eventPackage.startsWith(REVANCED_YOUTUBE_PREFIX)
            }
            targetPackage.startsWith(REVANCED_YOUTUBE_PREFIX) -> {
                eventPackage == YOUTUBE_PACKAGE_NAME || eventPackage.startsWith(REVANCED_YOUTUBE_PREFIX)
            }
            else -> targetPackage == eventPackage
        }
    }

    private fun customTrackedAppSettingKey(packageName: String): String {
        return "custom_app_" + packageName.replace(Regex("[^A-Za-z0-9]+"), "_")
    }

    private fun roundedBackground(color: Int): GradientDrawable {
        return GradientDrawable().apply {
            setColor(color)
            cornerRadius = dp(8).toFloat()
        }
    }

    private fun prominentRippleBackground(): RippleDrawable {
        return RippleDrawable(
            ColorStateList.valueOf(BRAND_PRESSED),
            roundedBackground(BRAND),
            roundedBackground(Color.WHITE),
        )
    }

    private fun textRippleBackground(): RippleDrawable {
        return RippleDrawable(
            ColorStateList.valueOf(BRAND_PRESSED),
            roundedBackground(Color.TRANSPARENT),
            roundedBackground(Color.WHITE),
        )
    }

    private fun outlinedBackground(): GradientDrawable {
        return roundedBackground(Color.TRANSPARENT).apply {
            setStroke(dp(2), BRAND)
        }
    }

    private fun outlinedRippleBackground(): RippleDrawable {
        return RippleDrawable(
            ColorStateList.valueOf(BRAND_PRESSED),
            outlinedBackground(),
            roundedBackground(Color.WHITE),
        )
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }

    companion object {
        const val EXTRA_SOURCE_PACKAGE_NAME = "source_package_name"
        const val EXTRA_APP_LABEL = "app_label"
        const val BRAND = 0xFF00688F.toInt()
        const val BRAND_PRESSED = 0xFF00A6D6.toInt()
        private const val PROMPT_PANEL_TAG = "prompt_panel"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val INSTAGRAM_PACKAGE_NAME = "com.instagram.android"
        private const val YOUTUBE_PACKAGE_NAME = "com.google.android.youtube"
        private const val REVANCED_YOUTUBE_PREFIX = "app.revanced.android.youtube"
        private const val INSTAGRAM_APP_LIMIT_SETTING_KEY = "instagram_app"
        private const val YOUTUBE_APP_LIMIT_SETTING_KEY = "youtube_app"
    }
}
