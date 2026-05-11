package com.prestige.tempus

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

internal class DurationWheelPicker(
    context: Context,
    private val values: IntArray,
    initialValue: Int = values.firstOrNull() ?: 0,
    private val labelBuilder: (Int) -> String,
    private val onSelectionChanged: ((Int) -> Unit)? = null,
) {
    private val pickerItemHeight = dp(context, 48)
    private val selectedIndex = intArrayOf(values.indexOf(initialValue).takeIf { it >= 0 } ?: 0)
    private val optionViews = mutableListOf<TextView>()
    private lateinit var pickerScroll: ScrollView

    val view: FrameLayout =
        FrameLayout(context).apply {
            addView(
                ScrollView(context).apply {
                    pickerScroll = this
                    isVerticalScrollBarEnabled = false
                    overScrollMode = View.OVER_SCROLL_NEVER
                    setBackgroundColor(Color.TRANSPARENT)
                    addView(
                        LinearLayout(context).apply {
                            orientation = LinearLayout.VERTICAL
                            setPadding(0, pickerItemHeight * 2, 0, pickerItemHeight * 2)
                            values.forEachIndexed { index, value ->
                                addView(
                                    TextView(context).apply {
                                        layoutParams = LinearLayout.LayoutParams(
                                            ViewGroup.LayoutParams.MATCH_PARENT,
                                            pickerItemHeight,
                                        )
                                        gravity = Gravity.CENTER
                                        text = labelBuilder(value)
                                        setOnClickListener {
                                            snapToIndex(index, animate = true)
                                        }
                                        optionViews += this
                                    },
                                )
                            }
                        },
                        ViewGroup.LayoutParams(
                            ViewGroup.LayoutParams.MATCH_PARENT,
                            ViewGroup.LayoutParams.WRAP_CONTENT,
                        ),
                    )
                    setOnScrollChangeListener { _, _, scrollY, _, _ ->
                        val liveIndex =
                            ((scrollY + (pickerItemHeight / 2f)) / pickerItemHeight).toInt()
                                .coerceIn(0, values.lastIndex)
                        updateSelectedOption(liveIndex)
                    }
                    setOnTouchListener { _, event ->
                        if (event.actionMasked == MotionEvent.ACTION_UP ||
                            event.actionMasked == MotionEvent.ACTION_CANCEL
                        ) {
                            postDelayed({ snapToNearest(animate = true) }, 60L)
                        }
                        false
                    }
                    post {
                        updateSelectedOption(selectedIndex[0])
                        snapToNearest(animate = false)
                    }
                },
                FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                ),
            )
            addView(
                View(context).apply {
                    setBackgroundColor(Color.rgb(215, 222, 231))
                },
                FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    dp(context, 2),
                    Gravity.CENTER_HORIZONTAL or Gravity.CENTER_VERTICAL,
                ).apply {
                    topMargin = -(pickerItemHeight / 2)
                },
            )
            addView(
                View(context).apply {
                    setBackgroundColor(Color.rgb(215, 222, 231))
                },
                FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    dp(context, 2),
                    Gravity.CENTER_HORIZONTAL or Gravity.CENTER_VERTICAL,
                ).apply {
                    topMargin = pickerItemHeight / 2
                },
            )
        }

    val heightPx: Int
        get() = pickerItemHeight * 5

    fun selectedValue(): Int = values[selectedIndex[0]]

    private fun updateSelectedOption(index: Int) {
        val clamped = index.coerceIn(0, values.lastIndex)
        selectedIndex[0] = clamped
        onSelectionChanged?.invoke(values[clamped])
        optionViews.forEachIndexed { optionIndex, textView ->
            val isSelected = optionIndex == clamped
            textView.setTextColor(
                if (isSelected) Color.rgb(17, 24, 39) else Color.rgb(95, 107, 122),
            )
            textView.textSize = if (isSelected) 21f else 16f
            textView.setTypeface(
                Typeface.DEFAULT,
                if (isSelected) Typeface.BOLD else Typeface.NORMAL,
            )
            textView.alpha = if (isSelected) 1f else 0.72f
        }
    }

    private fun snapToIndex(index: Int, animate: Boolean) {
        val snappedIndex = index.coerceIn(0, values.lastIndex)
        val targetY = snappedIndex * pickerItemHeight
        if (animate) {
            pickerScroll.smoothScrollTo(0, targetY)
        } else {
            pickerScroll.scrollTo(0, targetY)
        }
        updateSelectedOption(snappedIndex)
    }

    private fun snapToNearest(animate: Boolean) {
        val rawIndex =
            ((pickerScroll.scrollY + (pickerItemHeight / 2f)) / pickerItemHeight).toInt()
        val snappedIndex = rawIndex.coerceIn(0, values.lastIndex)
        snapToIndex(snappedIndex, animate)
    }
}

private fun dp(context: Context, value: Int): Int {
    return (value * context.resources.displayMetrics.density).toInt()
}
