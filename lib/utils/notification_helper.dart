import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  /// Khởi tạo thông báo (gọi khi mở app)
  static Future<void> initialize() async {
    // 🕒 Khởi tạo timezone cho Việt Nam (GMT+7) TRƯỚC KHI khởi tạo plugin
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

    const AndroidInitializationSettings androidInitSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
    InitializationSettings(android: androidInitSettings);

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification clicked: ${response.payload}');
      },
    );

    // ✅ YÊU CẦU QUYỀN THÔNG BÁO CHO ANDROID 13+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // ✅ TẠO NOTIFICATION CHANNEL (BẮT BUỘC CHO ANDROID 8.0+)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'daily_reminder_channel', // ID phải khớp với ID trong scheduleDailyNotification
      'Daily Reminders', // Tên hiển thị
      description: 'Thông báo nhắc nhở nhập giao dịch mỗi ngày',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    debugPrint('✅ Notification Helper đã khởi tạo xong');
  }

  /// Gửi thông báo ngay lập tức (test nhanh)
  static Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'daily_reminder_channel',
      'Daily Reminders',
      channelDescription: 'Thông báo nhắc nhở nhập giao dịch mỗi ngày',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _notificationsPlugin.show(
      0,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  /// Lên lịch thông báo hằng ngày vào giờ nhất định
  static Future<void> scheduleDailyNotification({
    required int hour,
    required int minute,
  }) async {
    // Hủy thông báo cũ trước
    await cancelDailyNotification();

    final scheduledTime = _nextInstanceOfTime(hour, minute);
    final now = tz.TZDateTime.now(tz.local);

    debugPrint('🕐 Giờ hiện tại (VN): ${now.toString()}');
    debugPrint('⏰ Giờ đặt lịch (VN): ${scheduledTime.toString()}');
    debugPrint('⏱️ Còn ${scheduledTime.difference(now).inMinutes} phút nữa đến giờ thông báo');

    await _notificationsPlugin.zonedSchedule(
      0,
      '🐋 Whales Spent nhắc nhở',
      'Đừng quên ghi lại giao dịch của bạn hôm nay nhé!',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder_channel',
          'Daily Reminders',
          channelDescription: 'Thông báo nhắc nhở nhập giao dịch mỗi ngày',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          icon: '@mipmap/ic_launcher',
          channelShowBadge: true,
          visibility: NotificationVisibility.public,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // Kiểm tra pending notifications
    final pendingNotifications = await _notificationsPlugin.pendingNotificationRequests();
    debugPrint('✅ Đã đặt lịch thông báo hằng ngày lúc: $hour:${minute.toString().padLeft(2, '0')} (Giờ VN)');
    debugPrint('📋 Số thông báo đang chờ: ${pendingNotifications.length}');

    for (var notification in pendingNotifications) {
      debugPrint('   - ID: ${notification.id}, Title: ${notification.title}');
    }
  }

  static Future<void> cancelDailyNotification() async {
    await _notificationsPlugin.cancel(0);
    debugPrint('🗑️ Đã hủy thông báo hằng ngày');
  }

  /// Kiểm tra quyền exact alarm (Android 12+)
  static Future<bool> checkExactAlarmPermission() async {
    final androidImpl = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImpl != null) {
      final canScheduleExactAlarms = await androidImpl.canScheduleExactNotifications();
      debugPrint('🔐 Quyền Exact Alarm: ${canScheduleExactAlarms == true ? "ĐÃ CẤP" : "CHƯA CẤP"}');
      return canScheduleExactAlarms ?? false;
    }

    return true; // Giả sử có quyền nếu không phải Android
  }

  /// Yêu cầu quyền exact alarm (Android 12+)
  static Future<void> requestExactAlarmPermission() async {
    final androidImpl = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImpl != null) {
      final canSchedule = await androidImpl.canScheduleExactNotifications();
      if (canSchedule == false) {
        debugPrint('⚠️ Chưa có quyền Exact Alarm, cần mở Settings để cấp quyền');
        // Ứng dụng cần hướng dẫn user vào Settings để bật quyền
      }
    }
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
