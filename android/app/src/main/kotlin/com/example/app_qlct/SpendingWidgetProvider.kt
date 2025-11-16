package com.example.app_qlct

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.app.PendingIntent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.util.Base64
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

/**
 * Widget Provider cho Whales Spent
 * Hiển thị thống kê chi tiêu tháng hiện tại trên màn hình chính Android
 */
class SpendingWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "SpendingWidget"
        private const val CHART_SIZE_DP = 104
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d(TAG, "onUpdate called for ${appWidgetIds.size} widgets")

        // Cập nhật tất cả widget instances
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        super.onReceive(context, intent)

        if (intent?.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            Log.d(TAG, "Widget update triggered via broadcast")
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        try {
            Log.d(TAG, "Updating widget ID: $appWidgetId")

            val views = RemoteViews(context.packageName, R.layout.widget_spending)

            // Đọc dữ liệu từ SharedPreferences
            val prefs = HomeWidgetPlugin.getData(context)
            val lastUpdate = prefs.getString("last_update", null)

            if (lastUpdate != null && lastUpdate.isNotEmpty()) {
                // CÓ DỮ LIỆU
                val monthYear = prefs.getString("month_year", "--/----") ?: "--/----"
                val topCategoriesJson = prefs.getString("top_categories", "[]") ?: "[]"

                // Set data
                views.setTextViewText(R.id.widget_month, monthYear)

                hideCategoryRows(views)

                val categories = parseTopCategories(topCategoriesJson)

                if (categories.isNotEmpty()) {
                    val colors = mutableListOf<Int>()

                    categories.take(3).forEachIndexed { index, category ->
                        val color = getColorForCategory(category)
                        colors.add(color)
                        bindCategoryRow(views, index, category, color)
                    }

                    if (colors.isNotEmpty()) {
                        drawPieChart(context, views, categories.take(colors.size), colors)
                    }

                    views.setViewVisibility(R.id.widget_content_container, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_empty_state, View.GONE)
                } else {
                    views.setViewVisibility(R.id.widget_content_container, View.GONE)
                    views.setViewVisibility(R.id.widget_empty_state, View.VISIBLE)
                }
            } else {
                // CHƯA CÓ DỮ LIỆU
                hideCategoryRows(views)
                views.setViewVisibility(R.id.widget_content_container, View.GONE)
                views.setViewVisibility(R.id.widget_empty_state, View.VISIBLE)
            }

            // Setup click để mở tab Statistics
            val intent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                addCategory(Intent.CATEGORY_LAUNCHER)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("open_tab", 3)
            }

            val pendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
            Log.d(TAG, "Widget $appWidgetId updated successfully")

        } catch (e: Exception) {
            Log.e(TAG, "Error updating widget $appWidgetId", e)
            e.printStackTrace()
        }
    }

    private fun parseTopCategories(json: String): List<CategoryData> {
        val list = mutableListOf<CategoryData>()
        try {
            if (json.isNotEmpty() && json != "[]") {
                val jsonArray = JSONArray(json)
                for (i in 0 until jsonArray.length()) {
                    val obj = jsonArray.getJSONObject(i)
                    list.add(
                        CategoryData(
                            name = obj.getString("name"),
                            amount = obj.getDouble("amount"),
                            percent = obj.getString("percent"),
                            icon = obj.optString("icon"),
                            categoryId = obj.optInt("category_id", i),
                            type = obj.optString("type", "expense"),
                            iconImage = obj.optString("icon_image", null)
                        )
                    )
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing categories", e)
        }
        return list
    }

    private fun drawPieChart(
        context: Context,
        views: RemoteViews,
        categories: List<CategoryData>,
        colors: List<Int>
    ) {
        try {
            val chartSize = (CHART_SIZE_DP * context.resources.displayMetrics.density).toInt()
            val bitmap = android.graphics.Bitmap.createBitmap(chartSize, chartSize, android.graphics.Bitmap.Config.ARGB_8888)
            val canvas = android.graphics.Canvas(bitmap)

            val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG)
            val gradientPaint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG)
            val rectF = android.graphics.RectF()

            val centerX = chartSize / 2f
            val centerY = chartSize / 2f
            val radius = chartSize / 2f - 10f

            rectF.set(centerX - radius, centerY - radius, centerX + radius, centerY + radius)

            // Tính tổng amount
            val total = categories.sumOf { it.amount }
            if (total <= 0) {
                views.setImageViewBitmap(R.id.widget_pie_chart, bitmap)
                return
            }
            var startAngle = -90f // Bắt đầu từ 12 giờ

            // Vẽ từng phần với gradient nhẹ
            categories.take(3).forEachIndexed { index, category ->
                val sweepAngle = ((category.amount / total) * 360f).toFloat()

                val color = colors.getOrNull(index % colors.size) ?: 0xFFFF6B6B.toInt()
                paint.style = android.graphics.Paint.Style.FILL
                paint.color = color
                canvas.drawArc(rectF, startAngle, sweepAngle, true, paint)

                // highlight border
                gradientPaint.style = android.graphics.Paint.Style.STROKE
                gradientPaint.strokeWidth = 6f
                gradientPaint.shader = android.graphics.LinearGradient(
                    centerX,
                    centerY - radius,
                    centerX,
                    centerY + radius,
                    color,
                    android.graphics.Color.WHITE,
                    android.graphics.Shader.TileMode.CLAMP
                )
                canvas.drawArc(rectF, startAngle, sweepAngle, false, gradientPaint)

                startAngle += sweepAngle
            }

            // Vòng tròn bên trong và viền
            paint.style = android.graphics.Paint.Style.FILL
            paint.color = 0xFF07182A.toInt()
            val innerRadius = radius * 0.58f
            canvas.drawCircle(centerX, centerY, innerRadius, paint)

            paint.style = android.graphics.Paint.Style.STROKE
            paint.strokeWidth = 4f
            paint.color = 0x3327C9E8
            canvas.drawCircle(centerX, centerY, radius, paint)

            // Nhãn trung tâm
            val textPaint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
                color = android.graphics.Color.WHITE
                textSize = chartSize * 0.16f
                textAlign = android.graphics.Paint.Align.CENTER
                typeface = android.graphics.Typeface.create(android.graphics.Typeface.DEFAULT_BOLD, android.graphics.Typeface.BOLD)
            }
            canvas.drawText("TOP", centerX, centerY - 4f, textPaint)
            textPaint.textSize = chartSize * 0.11f
            textPaint.color = 0xFF9CECFB.toInt()
            canvas.drawText("SPEND", centerX, centerY + textPaint.textSize, textPaint)

            // Set bitmap vào ImageView
            views.setImageViewBitmap(R.id.widget_pie_chart, bitmap)

            Log.d(TAG, "Pie chart drawn successfully with ${categories.size} categories")

        } catch (e: Exception) {
            Log.e(TAG, "Error drawing pie chart", e)
        }
    }

    private fun bindCategoryRow(
        views: RemoteViews,
        index: Int,
        category: CategoryData,
        color: Int
    ) {
        val rowIds = when (index) {
            0 -> Triple(R.id.category_1_row, R.id.category_1_name, R.id.category_1_percent)
            1 -> Triple(R.id.category_2_row, R.id.category_2_name, R.id.category_2_percent)
            2 -> Triple(R.id.category_3_row, R.id.category_3_name, R.id.category_3_percent)
            else -> null
        }

        val iconId = when (index) {
            0 -> R.id.category_1_icon
            1 -> R.id.category_2_icon
            2 -> R.id.category_3_icon
            else -> null
        }

        val colorBarId = when (index) {
            0 -> R.id.category_1_color_bar
            1 -> R.id.category_2_color_bar
            2 -> R.id.category_3_color_bar
            else -> null
        }

        if (rowIds != null && iconId != null && colorBarId != null) {
            val rowText = "${category.percent}%"

            views.setViewVisibility(rowIds.first, View.VISIBLE)
            views.setTextViewText(rowIds.second, category.name)
            views.setTextViewText(rowIds.third, rowText)

            val bitmap = decodeIconBitmap(category.iconImage)
            if (bitmap != null) {
                views.setImageViewBitmap(iconId, bitmap)
            } else {
                views.setImageViewResource(iconId, R.drawable.ic_default_category)
            }

            views.setInt(colorBarId, "setBackgroundColor", applyAlpha(color, 0.7f))
        }
    }

    private fun hideCategoryRows(views: RemoteViews) {
        val rows = listOf(
            R.id.category_1_row,
            R.id.category_2_row,
            R.id.category_3_row
        )

        rows.forEach { id ->
            views.setViewVisibility(id, View.GONE)
        }
    }

    private fun decodeIconBitmap(base64Data: String?): Bitmap? {
        if (base64Data.isNullOrBlank()) return null
        return try {
            val decoded = Base64.decode(base64Data, Base64.DEFAULT)
            BitmapFactory.decodeByteArray(decoded, 0, decoded.size)
        } catch (e: Exception) {
            Log.e(TAG, "Cannot decode icon bitmap", e)
            null
        }
    }

    private fun getColorForCategory(category: CategoryData): Int {
        val colorMap = mapOf(
            "Ăn uống" to 0xFFFF8A65.toInt(),
            "Di chuyển" to 0xFF4ECDC4.toInt(),
            "Mua sắm" to 0xFFFFC857.toInt(),
            "Hóa đơn" to 0xFF4ECDC4.toInt(),
            "Giải trí" to 0xFFFF9800.toInt(),
            "Y tế" to 0xFFE91E63.toInt(),
            "Giáo dục" to 0xFF9C27B0.toInt(),
            "Nhà cửa" to 0xFF795548.toInt(),
            "Xe cộ" to 0xFF607D8B.toInt(),
            "Điện thoại" to 0xFF3F51B5.toInt(),
            "Điện" to 0xFFFFEB3B.toInt(),
            "Nước" to 0xFF2196F3.toInt(),
            "Lương" to 0xFF4CAF50.toInt(),
            "Thưởng" to 0xFF8BC34A.toInt(),
            "Đầu tư" to 0xFF009688.toInt(),
            "Kinh doanh" to 0xFF03A9F4.toInt(),
            "Khác" to 0xFFFF9800.toInt()
        )

        return colorMap[category.name] ?: generateColorFromId(category.categoryId)
    }

    private fun generateColorFromId(id: Int): Int {
        val palette = listOf(
            0xFF64B5F6.toInt(), 0xFF4FC3F7.toInt(), 0xFF4DD0E1.toInt(),
            0xFF4DB6AC.toInt(), 0xFF81C784.toInt(), 0xFFAED581.toInt(),
            0xFFFFD54F.toInt(), 0xFFFFB74D.toInt(), 0xFFE57373.toInt(),
            0xFFBA68C8.toInt(), 0xFF9575CD.toInt(), 0xFF7986CB.toInt(),
            0xFF90A4AE.toInt(), 0xFFEF5350.toInt(), 0xFFAB47BC.toInt(),
            0xFF7E57C2.toInt(), 0xFF5C6BC0.toInt(), 0xFF42A5F5.toInt(),
            0xFF29B6F6.toInt(), 0xFF26C6DA.toInt(), 0xFF26A69A.toInt(),
            0xFF66BB6A.toInt(), 0xFF9CCC65.toInt(), 0xFFFFCA28.toInt(),
            0xFFFFA726.toInt(), 0xFF8D6E63.toInt(), 0xFF78909C.toInt(),
            0xFFEC407A.toInt(), 0xFFF06292.toInt(), 0xFFA1887F.toInt()
        )

        return palette[id % palette.size]
    }

    private fun applyAlpha(color: Int, alpha: Float): Int {
        val a = (Color.alpha(color) * alpha).toInt()
        val r = Color.red(color)
        val g = Color.green(color)
        val b = Color.blue(color)
        return Color.argb(a, r, g, b)
    }

    data class CategoryData(
        val name: String,
        val amount: Double,
        val percent: String,
        val icon: String?,
        val categoryId: Int,
        val type: String?,
        val iconImage: String?
    )
}
