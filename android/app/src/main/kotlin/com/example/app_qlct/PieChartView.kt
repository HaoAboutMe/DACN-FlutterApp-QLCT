package com.example.app_qlct

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.util.AttributeSet
import android.view.View
import kotlin.math.min

/**
 * Custom View để vẽ Pie Chart cho Widget
 */
class PieChartView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val rectF = RectF()

    // Dữ liệu biểu đồ
    private var sections: List<PieSection> = emptyList()
    private var total: Float = 0f

    // Màu sắc cho các section
    private val colors = listOf(
        0xFFFF6B6B.toInt(), // Đỏ
        0xFF4ECDC4.toInt(), // Xanh lá
        0xFFFFBE0B.toInt(), // Vàng
        0xFF8338EC.toInt(), // Tím
        0xFFFF006E.toInt(), // Hồng
        0xFF3A86FF.toInt(), // Xanh dương
    )

    fun setData(sections: List<PieSection>) {
        this.sections = sections
        this.total = sections.sumOf { it.value.toDouble() }.toFloat()
        invalidate() // Yêu cầu vẽ lại
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        if (sections.isEmpty() || total == 0f) {
            return
        }

        val size = min(width, height).toFloat()
        val centerX = width / 2f
        val centerY = height / 2f
        val radius = size / 2f - 20f // Padding 20px

        rectF.set(
            centerX - radius,
            centerY - radius,
            centerX + radius,
            centerY + radius
        )

        var startAngle = -90f // Bắt đầu từ 12 giờ

        sections.forEachIndexed { index, section ->
            val sweepAngle = (section.value / total) * 360f

            // Vẽ arc
            paint.style = Paint.Style.FILL
            paint.color = colors[index % colors.size]
            canvas.drawArc(rectF, startAngle, sweepAngle, true, paint)

            startAngle += sweepAngle
        }

        // Vẽ vòng tròn trắng ở giữa (để tạo donut chart)
        paint.color = 0xFF00A8CC.toInt() // Màu background widget
        val innerRadius = radius * 0.5f
        canvas.drawCircle(centerX, centerY, innerRadius, paint)
    }

    data class PieSection(
        val label: String,
        val value: Float,
        val color: Int? = null
    )
}
