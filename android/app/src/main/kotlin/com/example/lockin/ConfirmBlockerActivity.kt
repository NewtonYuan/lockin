package com.example.lockin

import android.app.Activity
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class ConfirmBlockerActivity : Activity() {
    private val minuteOptions = intArrayOf(1, 2, 3, 5, 10, 15, 30, 60)

    private val target: String
        get() = intent?.getStringExtra(EXTRA_TARGET) ?: TARGET_INSTAGRAM

    private val appLabel: String
        get() = when (target) {
            TARGET_YOUTUBE -> "YouTube"
            else -> "Instagram"
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(createConfirmationView())
    }

    @Deprecated("Back is intentionally disabled for this blocking prompt")
    override fun onBackPressed() {
        // Intentionally no-op. Exit paths should go through the prompt actions.
    }

    private fun createConfirmationView(): LinearLayout {
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.BLACK)
            setPadding(dp(24), dp(48), dp(24), dp(48))
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )

            addView(
                TextView(context).apply {
                    text = "Open $appLabel?"
                    setTextColor(Color.WHITE)
                    textSize = 30f
                    gravity = Gravity.CENTER
                    setTypeface(typeface, Typeface.BOLD)
                },
                LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                ),
            )

            addView(
                TextView(context).apply {
                    text = "Do you really want to open $appLabel right now?"
                    setTextColor(Color.rgb(216, 220, 226))
                    textSize = 18f
                    gravity = Gravity.CENTER
                    setPadding(0, dp(24), 0, dp(36))
                },
                LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                ),
            )

            addView(
                Button(context).apply {
                    text = "Not now"
                    setTextColor(Color.WHITE)
                    background = prominentRippleBackground()
                    setAllCaps(false)
                    textSize = 14f
                    setTypeface(typeface, Typeface.BOLD)
                    minHeight = dp(48)
                    setOnClickListener {
                        AppGuardAccessibilityService.dismissPrompt()
                        AppGuardAccessibilityService.returnToPreviousPageAfterPrompt()
                        finish()
                    }
                },
                buttonLayoutParams(),
            )

            addView(
                TextView(context).apply {
                    text = "Continue"
                    setTextColor(Color.WHITE)
                    textSize = 14f
                    gravity = Gravity.CENTER
                    setTypeface(typeface, Typeface.BOLD)
                    background = textRippleBackground()
                    setPadding(0, dp(18), 0, dp(18))
                    setOnClickListener {
                        setContentView(createMinutesView())
                    }
                },
                buttonLayoutParams(topMargin = dp(16)),
            )
        }
    }

    private fun createMinutesView(): LinearLayout {
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.BLACK)
            setPadding(dp(24), dp(48), dp(24), dp(48))
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )

            addView(
                TextView(context).apply {
                    text = "How many minutes?"
                    setTextColor(Color.WHITE)
                    textSize = 30f
                    gravity = Gravity.CENTER
                    setTypeface(typeface, Typeface.BOLD)
                },
                LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                ),
            )

            addView(
                TextView(context).apply {
                    text = "Choose how long $appLabel should stay open."
                    setTextColor(Color.rgb(216, 220, 226))
                    textSize = 18f
                    gravity = Gravity.CENTER
                    setPadding(0, dp(24), 0, dp(36))
                },
                LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                ),
            )

            minuteOptions.forEach { minutes ->
                addView(
                    Button(context).apply {
                        text = durationLabel(minutes)
                        setTextColor(Color.WHITE)
                        background = prominentRippleBackground()
                        setAllCaps(false)
                        textSize = 16f
                        setTypeface(typeface, Typeface.BOLD)
                        minHeight = dp(48)
                        setOnClickListener {
                            AppGuardAccessibilityService.allowTargetForMinutes(target, minutes)
                            finish()
                        }
                    },
                    buttonLayoutParams(topMargin = dp(8)),
                )
            }
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
        AppGuardAccessibilityService.dismissPrompt()
        super.onDestroy()
    }

    private fun buttonLayoutParams(topMargin: Int = 0): LinearLayout.LayoutParams {
        return LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT,
        ).apply {
            this.topMargin = topMargin
        }
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

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }

    companion object {
        const val EXTRA_TARGET = "target"
        const val TARGET_INSTAGRAM = "instagram"
        const val TARGET_YOUTUBE = "youtube"
        const val BRAND = 0xFF00688F.toInt()
        const val BRAND_PRESSED = 0xFF00A6D6.toInt()
    }
}
