package com.prestige.tempus

import android.app.Activity
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView

class PauseOnOpenActivity : Activity() {
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
                    TextView(context).apply {
                        text = "Do you really need this?"
                        setTextColor(Color.WHITE)
                        textSize = 30f
                        gravity = Gravity.CENTER
                        setTypeface(typeface, Typeface.BOLD)
                    },
                    matchWidthLayoutParams(),
                )

                addView(
                    TextView(context).apply {
                        text = "Open $appLabel anyway?"
                        setTextColor(Color.rgb(216, 220, 226))
                        textSize = 18f
                        gravity = Gravity.CENTER
                        setPadding(0, dp(24), 0, dp(36))
                    },
                    matchWidthLayoutParams(),
                )

                addView(
                    Button(context).apply {
                        text = "No, not really"
                        setTextColor(Color.WHITE)
                        background = prominentRippleBackground()
                        setAllCaps(false)
                        textSize = 14f
                        setTypeface(typeface, Typeface.BOLD)
                        minHeight = dp(48)
                        setOnClickListener {
                            AppGuardAccessibilityService.dismissPrompt()
                            AppGuardAccessibilityService.closePauseOnOpenTarget()
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
                            AppGuardAccessibilityService.allowPauseOnOpen(sourcePackageName)
                            finish()
                        }
                    },
                    buttonLayoutParams(topMargin = dp(16)),
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

    private fun promptFrame(): FrameLayout {
        return FrameLayout(this).apply {
            setBackgroundColor(Color.rgb(9, 13, 18))
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
        const val EXTRA_SOURCE_PACKAGE_NAME = "source_package_name"
        const val EXTRA_APP_LABEL = "app_label"
        const val BRAND = 0xFF00688F.toInt()
        const val BRAND_PRESSED = 0xFF00A6D6.toInt()
    }
}
