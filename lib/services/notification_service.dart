import 'dart:developer';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../database/database_helper.dart';
import '../models/loan.dart';
import '../models/notification_data.dart';

/// Service quản lý thông báo local và database
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Khởi tạo notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Khởi tạo timezone
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

      // Cấu hình cho Android
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      // Cấu hình cho iOS
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // Khởi tạo plugin
      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Yêu cầu quyền trên Android 13+
      await _requestPermissions();

      _isInitialized = true;
      log('NotificationService initialized successfully');
    } catch (e) {
      log('Error initializing NotificationService: $e');
    }
  }

  /// Yêu cầu quyền thông báo
  Future<void> _requestPermissions() async {
    final androidImplementation = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }

    final iosImplementation = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    if (iosImplementation != null) {
      await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  /// Xử lý khi người dùng bấm vào thông báo
  void _onNotificationTapped(NotificationResponse response) async {
    final payload = response.payload;
    if (payload != null) {
      log('Notification tapped with payload: $payload');
      // TODO: Navigate to loan detail or notification list
      // Có thể dùng Navigator key global hoặc event bus
    }
  }

  /// Hiển thị thông báo ngay lập tức
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'loan_reminders',
      'Nhắc nhở khoản vay',
      channelDescription: 'Thông báo nhắc nhở về các khoản vay sắp đến hạn',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(id, title, body, details, payload: payload);
  }

  /// Lên lịch thông báo
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'loan_reminders',
      'Nhắc nhở khoản vay',
      channelDescription: 'Thông báo nhắc nhở về các khoản vay sắp đến hạn',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  /// Hủy thông báo theo ID
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Hủy tất cả thông báo
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Kiểm tra và tạo thông báo cho các khoản vay sắp đến hạn
  /// Nên gọi hàm này mỗi ngày (qua background task hoặc khi mở app)
  Future<void> checkAndCreateLoanReminders() async {
    try {
      final dbHelper = DatabaseHelper();
      final now = DateTime.now();

      // Lấy tất cả khoản vay đang active và có bật nhắc nhở
      final loans = await dbHelper.getActiveLoansWithReminders();

      for (final loan in loans) {
        if (loan.dueDate == null || loan.reminderDays == null) continue;

        final daysUntilDue = loan.dueDate!.difference(now).inDays;

        // Kiểm tra nếu vẫn trong khoảng thời gian nhắc nhở
        if (daysUntilDue <= loan.reminderDays! && daysUntilDue >= 0) {
          await _createReminderForLoan(loan, daysUntilDue);
        }

        // Kiểm tra nếu đã quá hạn
        if (daysUntilDue < 0 && loan.status == 'active') {
          await _createOverdueNotification(loan);
          // Cập nhật trạng thái loan sang overdue
          await dbHelper.updateLoanStatus(loan.id!, 'overdue');
        }
      }
    } catch (e) {
      log('Error checking loan reminders: $e');
    }
  }

  /// Tạo thông báo nhắc nhở cho một khoản vay
  Future<void> _createReminderForLoan(Loan loan, int daysUntilDue) async {
    final dbHelper = DatabaseHelper();
    final now = DateTime.now();

    // Kiểm tra xem đã gửi thông báo cho ngày hôm nay chưa
    final lastSent = loan.lastReminderSent;
    if (lastSent != null) {
      final hoursSinceLastSent = now.difference(lastSent).inHours;
      if (hoursSinceLastSent < 20) {
        // Đã gửi trong vòng 20 giờ, không gửi lại
        return;
      }
    }

    // Tạo nội dung thông báo
    String title, body;
    String type;

    if (daysUntilDue == 0) {
      type = 'due_today';
      title = 'Khoản ${loan.loanType == 'lend' ? 'cho vay' : 'đi vay'} đến hạn hôm nay!';
      body = '${loan.personName} - ${_formatAmount(loan.amount)} đến hạn thanh toán hôm nay.';
    } else {
      type = 'reminder';
      title = 'Nhắc nhở: Khoản ${loan.loanType == 'lend' ? 'cho vay' : 'đi vay'} sắp đến hạn';
      body = '${loan.personName} - ${_formatAmount(loan.amount)} còn $daysUntilDue ngày nữa đến hạn.';
    }

    // Lưu vào database
    final notification = NotificationData(
      loanId: loan.id,
      type: type,
      title: title,
      body: body,
      sentAt: now,
      isRead: false,
    );

    await dbHelper.insertNotification(notification);

    // Hiển thị thông báo local
    await showNotification(
      id: loan.id!,
      title: title,
      body: body,
      payload: 'loan_${loan.id}',
    );

    // Cập nhật thời gian gửi cuối
    await dbHelper.updateLoanLastReminderSent(loan.id!, now);
  }

  /// Tạo thông báo khi khoản vay quá hạn
  Future<void> _createOverdueNotification(Loan loan) async {
    final dbHelper = DatabaseHelper();
    final now = DateTime.now();
    final daysOverdue = now.difference(loan.dueDate!).inDays;

    // Kiểm tra xem đã có thông báo overdue chưa
    final existingNotifications = await dbHelper.getNotificationsByLoanId(loan.id!);
    final hasOverdueNotification = existingNotifications.any(
      (n) => n.type == 'overdue' && n.sentAt.isAfter(loan.dueDate!),
    );

    if (hasOverdueNotification) return;

    final title = 'Khoản ${loan.loanType == 'lend' ? 'cho vay' : 'đi vay'} đã quá hạn!';
    final body = '${loan.personName} - ${_formatAmount(loan.amount)} đã quá hạn $daysOverdue ngày.';

    // Lưu vào database
    final notification = NotificationData(
      loanId: loan.id,
      type: 'overdue',
      title: title,
      body: body,
      sentAt: now,
      isRead: false,
    );

    await dbHelper.insertNotification(notification);

    // Hiển thị thông báo local
    await showNotification(
      id: loan.id! + 10000, // Offset để tránh trùng ID
      title: title,
      body: body,
      payload: 'loan_${loan.id}',
    );
  }

  /// Đếm số thông báo chưa đọc
  Future<int> getUnreadNotificationCount() async {
    final dbHelper = DatabaseHelper();
    return await dbHelper.getUnreadNotificationCount();
  }

  /// Đếm số khoản vay sắp đến hạn (trong vòng 7 ngày)
  Future<int> getUpcomingLoansCount() async {
    final dbHelper = DatabaseHelper();
    final now = DateTime.now();
    final loans = await dbHelper.getActiveLoansWithReminders();

    return loans.where((loan) {
      if (loan.dueDate == null) return false;
      final daysUntilDue = loan.dueDate!.difference(now).inDays;
      return daysUntilDue >= 0 && daysUntilDue <= 7;
    }).length;
  }

  /// Format số tiền
  String _formatAmount(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}tr';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}k';
    }
    return amount.toStringAsFixed(0);
  }
}

