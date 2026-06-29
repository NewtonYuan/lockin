package com.prestige.tempus

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.os.CountDownTimer
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
import androidx.activity.ComponentActivity

class ConfirmBlockerActivity : ComponentActivity() {
    private val minuteOptions = intArrayOf(1, 2, 3, 5, 10, 15, 30, 60)
    private var bypassCountdown: CountDownTimer? = null

    private val target: String
        get() = intent?.getStringExtra(EXTRA_TARGET) ?: TARGET_INSTAGRAM

    private val appLabel: String
        get() = intent?.getStringExtra(EXTRA_APP_LABEL)
            ?.takeIf { it.isNotBlank() }
            ?: when (target) {
                TARGET_YOUTUBE -> "YouTube"
                else -> "Instagram"
            }

    private val blockedLabel: String
        get() = when (target) {
            TARGET_YOUTUBE -> "Shorts"
            else -> "Reels"
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        configureEdgeToEdgePromptWindow()
        setPromptContent(createConfirmationView())
        overridePendingTransition(R.anim.prompt_fade_in, R.anim.prompt_fade_out)
    }

    @Deprecated("Back is intentionally disabled for this blocking prompt")
    override fun onBackPressed() {
        // Intentionally no-op. Exit paths should go through the prompt actions.
    }

    private fun createConfirmationView(): FrameLayout {
        val bypassButton = Button(this)

        return promptFrame().apply {
            addView(promptPanel().apply {
                addView(
                    logoView(),
                    logoLayoutParams(),
                )

                addView(
                    TextView(context).apply {
                        text = blockedTitle(blockedLabel)
                        setTextColor(Color.rgb(17, 24, 39))
                        textSize = 30f
                        gravity = Gravity.CENTER
                        setTypeface(typeface, Typeface.BOLD)
                    },
                    matchWidthLayoutParams(),
                )

                addView(
                    Button(context).apply {
                        text = "Go Back"
                        setTextColor(Color.WHITE)
                        background = prominentRippleBackground()
                        setAllCaps(false)
                        textSize = 16f
                        setTypeface(typeface, Typeface.BOLD)
                        minHeight = dp(48)
                        setPadding(dp(16), 0, dp(16), 0)
                        setOnClickListener {
                            AppGuardAccessibilityService.dismissPrompt()
                            AppGuardAccessibilityService.returnToPreviousPageAfterPrompt()
                            finish()
                        }
                    },
                    buttonLayoutParams(topMargin = dp(40)),
                )

                addView(
                    bypassButton.apply {
                        tag = BYPASS_BUTTON_TAG
                        text = "Bypass this time"
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
                        text = "This will affect your daily streak"
                        setTextColor(Color.rgb(95, 107, 122))
                        textSize = 11f
                        gravity = Gravity.CENTER
                        setPadding(0, dp(6), 0, 0)
                    },
                    matchWidthLayoutParams(),
                )
            })
        }
    }

    private fun createMinutesView(): FrameLayout {
        val picker = DurationWheelPicker(
            context = this,
            values = minuteOptions,
            initialValue = 1,
            labelBuilder = ::durationLabel,
        )

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
                            AppGuardAccessibilityService.allowTargetForMinutes(
                                target,
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
                            AppGuardAccessibilityService.returnToPreviousPageAfterPrompt()
                            finish()
                        }
                    },
                    buttonLayoutParams(topMargin = dp(10)),
                )
            })
        }
    }

    private fun durationLabel(minutes: Int): String {
        return when (minutes) {
            1 -> "1 minute"
            60 -> "1 hour"
            else -> "$minutes minutes"
        }
    }

    override fun onDestroy() {
        bypassCountdown?.cancel()
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
        bypassCountdown?.cancel()
        setContentView(view)
        val bypassButton = view.findViewWithTag<Button>(BYPASS_BUTTON_TAG)
        if (bypassButton != null) {
            view.post {
                startBypassDelay(bypassButton, "Bypass this time")
            }
        }
        val panel = (view as? ViewGroup)?.findViewWithTag<View>(PROMPT_PANEL_TAG) ?: view
        panel.alpha = 0f
        panel.animate()
            .alpha(1f)
            .setDuration(140L)
            .start()
    }

    private fun startBypassDelay(
        button: Button,
        enabledLabel: String,
    ) {
        bypassCountdown?.cancel()

        val bypassDelayMs = resolveBypassDelayMs()
        if (bypassDelayMs <= 0L) {
            button.text = enabledLabel
            button.isEnabled = true
            button.alpha = 1f
            return
        }

        button.isEnabled = false
        button.alpha = 0.55f
        bypassCountdown = object : CountDownTimer(bypassDelayMs, 1000L) {
            override fun onTick(millisUntilFinished: Long) {
                val secondsRemaining = ((millisUntilFinished + 999L) / 1000L).toInt()
                button.text = "$enabledLabel (${secondsRemaining}s)"
            }

            override fun onFinish() {
                button.text = enabledLabel
                button.isEnabled = true
                button.alpha = 1f
            }
        }.start()
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
            applySystemBarPadding()
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

    private fun blockedTitle(label: String): CharSequence {
        val title = "$label is\u00A0Blocked"
        val spannable = SpannableString(title)
        val blockedStart = title.lastIndexOf("Blocked")
        if (blockedStart >= 0) {
            spannable.setSpan(
                ForegroundColorSpan(BRAND),
                blockedStart,
                title.length,
                Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
            )
        }
        return spannable
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
        const val EXTRA_TARGET = "target"
        const val EXTRA_APP_LABEL = "app_label"
        const val TARGET_INSTAGRAM = "instagram"
        const val TARGET_YOUTUBE = "youtube"
        const val BRAND = 0xFF00688F.toInt()
        const val BRAND_PRESSED = 0xFF00A6D6.toInt()
        private const val PROMPT_PANEL_TAG = "prompt_panel"
        private const val BYPASS_BUTTON_TAG = "bypass_button"
    }

    private fun resolveBypassDelayMs(): Long {
        val prefs = getSharedPreferences(AppGuardAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
        val seconds = prefs.getInt(
            AppGuardAccessibilityService.PAUSE_DURATION_SECONDS_PREF_KEY,
            AppGuardAccessibilityService.DEFAULT_PAUSE_DURATION_SECONDS,
        ).coerceIn(0, 15)
        return seconds * 1_000L
    }
}
