package com.shibu.wallpaper.github_wallpaper

import android.graphics.*
import android.service.wallpaper.WallpaperService
import android.view.SurfaceHolder
import android.content.Context
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*
import android.util.Log
import kotlin.math.sin

class WallpaperService : WallpaperService() {

    override fun onCreateEngine(): Engine {
        return GithubWallpaperEngine()
    }

    inner class GithubWallpaperEngine : Engine() {
        private val handler = android.os.Handler(android.os.Looper.getMainLooper())
        private val drawRunnable = Runnable { draw() }
        private var visible = false
        private val animationFps = 15L  // Reduced from 24 for battery efficiency
        private val frameDelay = 1000L / animationFps

        // Data cache — read prefs every 30s instead of every frame
        private var cachedJsonStr: String? = null
        private var lastPrefsRead = 0L
        private val prefsCacheDuration = 30_000L // 30 seconds

        override fun onVisibilityChanged(visible: Boolean) {
            this.visible = visible
            if (visible) draw() else handler.removeCallbacks(drawRunnable)
        }

        override fun onSurfaceDestroyed(holder: SurfaceHolder) {
            super.onSurfaceDestroyed(holder)
            this.visible = false
            handler.removeCallbacks(drawRunnable)
        }

        private fun draw() {
            if (!visible) return
            val holder = surfaceHolder
            var canvas: Canvas? = null
            try {
                canvas = holder.lockCanvas()
                if (canvas != null) {
                    try {
                        drawWallpaper(canvas)
                    } catch (e: Exception) {
                        // Crash fallback — always show solid black rather than a broken wallpaper
                        canvas.drawColor(Color.BLACK)
                        Log.e("GitGlow", "Wallpaper render error: ${e.message}", e)
                    }
                }
            } finally {
                if (canvas != null) holder.unlockCanvasAndPost(canvas)
            }
            handler.removeCallbacks(drawRunnable)
            if (visible) handler.postDelayed(drawRunnable, frameDelay)
        }

        private fun drawWallpaper(canvas: Canvas) {
            val width = canvas.width.toFloat()
            val height = canvas.height.toFloat()

            canvas.drawColor(Color.BLACK)

            // Read prefs from cache or refresh every 30s
            val now = System.currentTimeMillis()
            if (cachedJsonStr == null || now - lastPrefsRead > prefsCacheDuration) {
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                cachedJsonStr = prefs.getString("flutter.github_data_json", null)
                lastPrefsRead = now
            }
            val jsonStr = cachedJsonStr
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val username = prefs.getString("flutter.username", "User")
            
            // Safe helper to read Flutter doubles as Floats
            fun getFlutterFloat(key: String, default: Float): Float {
                return try {
                    val value = prefs.all[key]
                    when (value) {
                        is Float -> value
                        is Double -> value.toFloat()
                        is Int -> value.toFloat()
                        is Long -> value.toFloat()
                        else -> default
                    }
                } catch (e: Exception) { default }
            }

            // Dynamic Layout Offsets
            val yDateOffset = getFlutterFloat("flutter.layout_y_date", -400f)
            val yMapOffset = getFlutterFloat("flutter.layout_y_map", -180f)
            val yTotalOffset = getFlutterFloat("flutter.layout_y_total", 130f)
            val yUserOffset = getFlutterFloat("flutter.layout_y_user", 250f)
            val yInfoOffset = getFlutterFloat("flutter.layout_y_info", 450f)
            val fontFamily = prefs.getString("flutter.font_family", "sans-serif") ?: "sans-serif"

            if (jsonStr == null) {
                drawMessage(canvas, "Login & Sync in App", width, height)
                return
            }

            try {
                val viewer = JSONObject(jsonStr).getJSONObject("data").getJSONObject("viewer")
                val cal = viewer.getJSONObject("contributionsCollection").getJSONObject("contributionCalendar")
                val weeks = cal.getJSONArray("weeks")

                val currentYear = 2026
                val monthsData = Array(12) { mutableListOf<Int>() }
                val monthTotals = IntArray(12) { 0 }
                var total2026 = 0

                val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.US)
                val calendar = Calendar.getInstance()

                for (i in 0 until weeks.length()) {
                    val days = weeks.getJSONObject(i).getJSONArray("contributionDays")
                    for (j in 0 until days.length()) {
                        val day = days.getJSONObject(j)
                        val dateStr = day.getString("date")
                        val count = day.getInt("contributionCount")

                        val date = sdf.parse(dateStr) ?: continue
                        calendar.time = date
                        
                        if (calendar.get(Calendar.YEAR) == currentYear) {
                            val month = calendar.get(Calendar.MONTH)
                            monthsData[month].add(count)
                            monthTotals[month] += count
                            total2026 += count
                        }
                    }
                }

                val centerY = height / 2
                val time = System.currentTimeMillis()

                // Dynamic grid height — grows with more months, capped at 50% of screen
                val nonEmptyMonths = monthsData.count { it.isNotEmpty() }.coerceAtLeast(1)
                val rowHeight = 42f  // approximate height per month row (dot + gap)
                val gridHeight = (nonEmptyMonths * rowHeight).coerceIn(200f, height * 0.50f)
                val gridBottom = centerY + yMapOffset + gridHeight

                // 2. SPARKLE GRID
                drawCleanSparkleGrid(canvas, monthsData, width, centerY + yMapOffset, gridHeight, time)

                // 3. STATS TEXT — 150px below grid bottom
                drawYearTotal(canvas, total2026, currentYear, width, gridBottom + 150f, fontFamily)

                // 5. INFO STRIP (Graph)
                drawModernInfoStrip(canvas, monthTotals, width, gridBottom + 230f, 240f)

                // 6. DEVELOPER CREDIT (Just below the info strip)
                drawDeveloperCredit(canvas, width, gridBottom + 230f + 240f + 30f)

            } catch (e: Exception) {
                drawMessage(canvas, "Refresh data in App", width, height)
            }
        }

        private fun drawPillContainer(canvas: Canvas, text: String, sw: Float, y: Float, radius: Float, alpha: Int, isSignature: Boolean, font: String) {
            val paint = Paint().apply {
                isAntiAlias = true
                color = Color.WHITE
                textSize = if (font == "cursive") 48f else 36f
                textAlign = Paint.Align.CENTER
                typeface = Typeface.create(font, if (font == "cursive") Typeface.NORMAL else Typeface.BOLD)
                if (font != "cursive") letterSpacing = 0.05f
            }
            
            val displayText = if (font == "cursive") text else text.uppercase()
            val bounds = Rect()
            paint.getTextBounds(displayText, 0, displayText.length, bounds)
            val pillW = (bounds.width() + 150f).coerceAtLeast(340f)
            val pillH = 80f
            val rect = RectF(sw/2 - pillW/2, y - pillH/2, sw/2 + pillW/2, y + pillH/2)
            
            val glass = Paint().apply {
                isAntiAlias = true
                color = Color.WHITE
                setAlpha(alpha)
            }
            canvas.drawRoundRect(rect, radius, radius, glass)
            
            val border = Paint(glass).apply {
                style = Paint.Style.STROKE
                strokeWidth = 1.5f
                setAlpha(alpha + 20)
            }
            canvas.drawRoundRect(rect, radius, radius, border)
            
            paint.setAlpha(255)
            canvas.drawText(displayText, sw/2, y + (bounds.height() / 2) - 2f, paint)
        }

        private fun drawCleanSparkleGrid(canvas: Canvas, data: Array<MutableList<Int>>, sw: Float, y: Float, h: Float, time: Long) {
            // Dynamic sizing based on screen dimensions
            val maxDaysInRow = data.maxOfOrNull { it.size } ?: 31
            // Each dot slot = dotRadius*2 (diameter) + dotGap; occupy 75% of screen width
            val slotCount = maxDaysInRow.coerceAtLeast(1)
            val totalSlotWidth = sw * 0.75f
            // dot slot = dotRadius*2 + gap; gap = dotRadius → slot = 3*dotRadius
            val dotRadius = (totalSlotWidth / (slotCount * 3f)).coerceIn(2f, 12f)
            val dotGap = dotRadius  // gap equals radius for clean spacing
            val rowGap = ((h - (12 * dotRadius * 2)) / 11f).coerceAtLeast(4f)
            val paint = Paint().apply { isAntiAlias = true }
            
            for (m in 0 until 12) {
                val rowY = y + m * (dotRadius * 2 + rowGap)
                val days = data[m]
                if (days.isEmpty()) continue
                val rowWidth = (days.size * dotRadius * 2) + ((days.size - 1) * dotGap)
                val startX = (sw - rowWidth) / 2
                
                for (d in 0 until days.size) {
                    val count = days[d]
                    val dx = startX + d * (dotRadius * 2 + dotGap) + dotRadius
                    val dy = rowY + dotRadius
                    
                    if (count > 0) {
                        paint.style = Paint.Style.FILL
                        paint.color = Color.WHITE
                        val cycle = (sin(time / 650.0 + d * 0.45 + m * 0.9) + 1.0) / 2.0
                        val baseAlpha = (140 + (count * 25)).coerceAtMost(255)
                        paint.alpha = (baseAlpha * (0.65 + 0.35 * cycle)).toInt()
                        
                        if (cycle > 0.88) {
                            val glow = Paint(paint).apply {
                                maskFilter = BlurMaskFilter(15f, BlurMaskFilter.Blur.OUTER)
                            }
                            canvas.drawCircle(dx, dy, dotRadius + 1f, glow)
                        }
                        canvas.drawCircle(dx, dy, dotRadius, paint)
                    } else {
                        paint.style = Paint.Style.FILL
                        paint.color = Color.parseColor("#161B22")
                        paint.alpha = 255
                        canvas.drawCircle(dx, dy, dotRadius, paint)
                    }
                }
            }
        }

        private fun drawYearTotal(canvas: Canvas, total: Int, year: Int, sw: Float, y: Float, font: String) {
            val paint = Paint().apply {
                isAntiAlias = true
                color = Color.WHITE
                alpha = 140
                textSize = 38f
                textAlign = Paint.Align.CENTER
                typeface = Typeface.create(font, Typeface.NORMAL)
            }
            canvas.drawText("$total contributions in $year", sw/2, y + 15f, paint)
        }

        private fun drawModernInfoStrip(canvas: Canvas, totals: IntArray, sw: Float, y: Float, h: Float) {
            val paint = Paint().apply { isAntiAlias = true }
            val rect = RectF(70f, y, sw - 70f, y + h)
            
            // Grey background removed per user request
            
            val months = arrayOf("J","F","M","A","M","J","J","A","S","O","N","D")
            val padding = 55f
            val itemWidth = (rect.width() - padding * 2) / 12

            for (i in 0 until 12) {
                val cx = rect.left + padding + i * itemWidth + itemWidth / 2
                val maxBarH = h * 0.5f
                val maxContri = (totals.maxOrNull() ?: 1).coerceAtLeast(1)
                val barH = (totals[i].toFloat() / maxContri.toFloat()) * maxBarH
                
                val barW = 8f
                val barRect = RectF(cx - barW/2, rect.bottom - 55f - barH, cx + barW/2, rect.bottom - 55f)
                
                paint.color = Color.WHITE
                paint.alpha = 255
                canvas.drawRoundRect(barRect, barW/2, barW/2, paint)
                
                paint.textSize = 24f
                paint.alpha = 160
                paint.textAlign = Paint.Align.CENTER
                canvas.drawText(months[i], cx, rect.bottom - 15f, paint)

                if (totals[i] > 0) {
                    paint.textSize = 22f
                    paint.alpha = 255
                    paint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                    canvas.drawText("${totals[i]}", cx, barRect.top - 12f, paint)
                    paint.typeface = Typeface.DEFAULT
                }
            }
        }

        private fun drawDeveloperCredit(canvas: Canvas, sw: Float, y: Float) {
            val paint = Paint().apply {
                isAntiAlias = true
                color = Color.WHITE
                alpha = 80 
                textSize = 28f
                textAlign = Paint.Align.CENTER
                typeface = Typeface.create("sans-serif-thin", Typeface.NORMAL)
            }
            canvas.drawText("~Developed By Swayanshu", sw / 2, y, paint)
        }

        private fun drawMessage(canvas: Canvas, msg: String, width: Float, height: Float) {
            val paint = Paint().apply {
                color = Color.GRAY
                textSize = 40f
                textAlign = Paint.Align.CENTER
                isAntiAlias = true
            }
            canvas.drawText(msg, width / 2, height / 2, paint)
        }
    }
}
