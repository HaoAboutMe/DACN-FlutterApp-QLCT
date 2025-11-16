package com.example.app_qlct

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.app_qlct/widget"
    private var widgetChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        widgetChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPinWidget" -> handleRequestPinWidget(result)
                    "hasPinnedWidget" -> result.success(hasPinnedWidget())
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Xử lý intent từ widget click
        handleWidgetIntent()
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleWidgetIntent()
    }

    private fun handleWidgetIntent() {
        intent?.let {
            if (it.hasExtra("open_tab")) {
                val tabIndex = it.getIntExtra("open_tab", 0)

                // Gửi message cho Flutter để chuyển tab
                if (widgetChannel != null) {
                    widgetChannel?.invokeMethod("openTab", tabIndex)
                } else {
                    flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                        MethodChannel(messenger, CHANNEL).invokeMethod("openTab", tabIndex)
                    }
                }
            }
        }
    }

    private fun hasPinnedWidget(): Boolean {
        val manager = getSystemService(AppWidgetManager::class.java) ?: return false
        val componentName = ComponentName(this, SpendingWidgetProvider::class.java)
        val ids = manager.getAppWidgetIds(componentName)
        return ids != null && ids.isNotEmpty()
    }

    private fun handleRequestPinWidget(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.error("unsupported", "Tính năng cần Android 8.0 trở lên", null)
            return
        }

        val manager = getSystemService(AppWidgetManager::class.java)
        if (manager == null) {
            result.error("manager_null", "AppWidgetManager unavailable", null)
            return
        }

        val componentName = ComponentName(this, SpendingWidgetProvider::class.java)
        val existingIds = manager.getAppWidgetIds(componentName)
        if (existingIds != null && existingIds.isNotEmpty()) {
            result.success(true)
            return
        }

        if (!manager.isRequestPinAppWidgetSupported) {
            result.success(false)
            return
        }

        val success = manager.requestPinAppWidget(componentName, null, null)
        result.success(success)
    }
}
