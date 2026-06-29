package com.prestige.tempus

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
import androidx.activity.ComponentActivity

class DailyLimitReachedActivity : ComponentActivity() {
    private val sourcePackageName: String?
        get() = intent?.getStringExtra(EXTRA_SOURCE_PACKAGE_NAME)

    private val appLabel: String
        get() = intent?.getStringExtra(EXTRA_APP_LABEL)
            ?.takeIf { it.isNotBlank() }
            ?: "This app"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        configureEdgeToEdgePromptWindow()
        setPromptContent(createConfirmationView())
        overridePendingTransition(R.anim.prompt_fade_in, R.anim.prompt_fade_out)
    }

    @Deprecated("Back is intentionally disabled for this prompt")
    override fun onBackPressed() {
        // Intentionally no-op.
    }

    private fun createConfirmationView(): FrameLayout {
        return promptFrame().apply {
            addView(promptPanel().apply {
                addView(logoView(), logoLayoutParams())

                addView(
                    TextView(context).apply {
                        text = titleText(appLabel)
                        setTextColor(Color.rgb(17, 24, 39))
                        textSize = 30f
                        gravity = Gravity.CENTER
                        setTypeface(typeface, Typeface.BOLD)
                    },
                    matchWidthLayoutParams(),
                )

                addView(
                    Button(context).apply {
                        text = "Okay"
                        setTextColor(Color.WHITE)
                        background = prominentRippleBackground()
                        setAllCaps(false)
                        textSize = 16f
                        setTypeface(typeface, Typeface.BOLD)
                        minHeight = dp(48)
                        setPadding(dp(16), 0, dp(16), 0)
                        setOnClickListener {
                            AppGuardAccessibilityService.dismissPrompt()
                            AppGuardAccessibilityService.closeDailyLimitTarget()
                            finish()
                        }
                    },
                    buttonLayoutParams(topMargin = dp(40)),
                )
            })
        }
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
        panel.animate().alpha(1f).setDuration(140L).start()
    }

    private fun titleText(label: String): CharSequence {
        val title = "$label limit reached"
        val spannable = SpannableString(title)
        val reachedStart = title.lastIndexOf("reached")
        if (reachedStart >= 0) {
            spannable.setSpan(
                ForegroundColorSpan(BRAND),
                reachedStart,
                title.length,
                Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
            )
        }
        return spannable
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

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }

    companion object {
        const val EXTRA_SOURCE_PACKAGE_NAME = "source_package_name"
        const val EXTRA_APP_LABEL = "app_label"
        const val BRAND = 0xFF00688F.toInt()
        const val BRAND_PRESSED = 0xFF00A6D6.toInt()
        private const val PROMPT_PANEL_TAG = "prompt_panel"
    }
}
