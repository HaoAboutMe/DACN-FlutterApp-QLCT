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
                invokeWidgetMethod("openTab", tabIndex)
                it.removeExtra("open_tab")
            }

            if (it.getBooleanExtra("open_widget_quick_actions", false)) {
                invokeWidgetMethod("openWidgetShortcutManager", null)
                it.removeExtra("open_widget_quick_actions")
            }

            if (it.getBooleanExtra("open_quick_action", false)) {
                val payload = hashMapOf(
                    "type" to it.getStringExtra("quick_action_type"),
                    "shortcut_type" to it.getStringExtra("quick_action_shortcut_type"),
                    "category_id" to it.getIntExtra("quick_action_category_id", -1),
                    "category_name" to it.getStringExtra("quick_action_category_name"),
                    "icon" to it.getStringExtra("quick_action_category_icon"),
                    "label" to it.getStringExtra("quick_action_label"),
                    "amount" to it.getDoubleExtra("quick_action_amount", 0.0),
                    "is_quick_add" to it.getBooleanExtra("quick_action_is_quick_add", false),
                    "feature_id" to it.getStringExtra("quick_action_feature_id"),
                    "slot" to it.getIntExtra("quick_action_slot", -1)
                )

                invokeWidgetMethod("handleQuickAction", payload)
                it.removeExtra("open_quick_action")
            }
        }
    }

    private fun invokeWidgetMethod(method: String, arguments: Any?) {
        if (widgetChannel != null) {
            widgetChannel?.invokeMethod(method, arguments)
        } else {
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, CHANNEL).invokeMethod(method, arguments)
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
