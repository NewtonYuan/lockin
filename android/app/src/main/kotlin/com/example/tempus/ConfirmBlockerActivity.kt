package com.prestige.tempus

import android.app.Activity
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

class ConfirmBlockerActivity : Activity() {
    private val minuteOptions = intArrayOf(1, 2, 3, 5, 10, 15, 30, 60)

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
        window.setBackgroundDrawableResource(android.R.color.transparent)
        setPromptContent(createConfirmationView())
        overridePendingTransition(R.anim.prompt_fade_in, R.anim.prompt_fade_out)
    }

    @Deprecated("Back is intentionally disabled for this blocking prompt")
    override fun onBackPressed() {
        // Intentionally no-op. Exit paths should go through the prompt actions.
    }

    private fun createConfirmationView(): FrameLayout {
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
                        textSize = 34f
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
                    buttonLayoutParams(topMargin = dp(28)),
                )

                addView(
                    Button(context).apply {
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
            })
        }
    }

    private fun createMinutesView(): FrameLayout {
        return promptFrame().apply {
            addView(promptPanel().apply {
                addView(
                    logoView(),
                    logoLayoutParams(),
                )

                addView(
                    TextView(context).apply {
                        text = "How many minutes?"
                        setTextColor(Color.rgb(17, 24, 39))
                        textSize = 34f
                        gravity = Gravity.CENTER
                        setTypeface(typeface, Typeface.BOLD)
                    },
                    matchWidthLayoutParams(),
                )

                minuteOptions.forEach { minutes ->
                    addView(
                        Button(context).apply {
                            text = durationLabel(minutes)
                            setTextColor(Color.WHITE)
                            background = prominentRippleBackground()
                            setAllCaps(false)
                            textSize = 18f
                            setTypeface(typeface, Typeface.BOLD)
                            minHeight = dp(48)
                            setPadding(dp(16), 0, dp(16), 0)
                            setOnClickListener {
                                AppGuardAccessibilityService.allowTargetForMinutes(target, minutes)
                                finish()
                            }
                        },
                        buttonLayoutParams(topMargin = dp(8)),
                    )
                }
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
        AppGuardAccessibilityService.dismissPrompt()
        super.onDestroy()
    }

    override fun finish() {
        val content = window.decorView.findViewById<ViewGroup>(android.R.id.content)
        val root = content.getChildAt(0)
        if (root == null) {
            super.finish()
            overridePendingTransition(R.anim.prompt_fade_in, R.anim.prompt_fade_out)
            return
        }

        root.animate()
            .alpha(0f)
            .setDuration(110L)
            .withEndAction {
                super.finish()
                overridePendingTransition(R.anim.prompt_fade_in, R.anim.prompt_fade_out)
            }
            .start()
    }

    private fun setPromptContent(view: View) {
        view.alpha = 0f
        setContentView(view)
        view.animate()
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
            bottomMargin = dp(18)
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
    }
}
