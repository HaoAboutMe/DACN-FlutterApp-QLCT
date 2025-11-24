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

    log('Scheduled notification ID: $id for ${scheduledDate.toString()}');
  }

  /// Lên lịch thông báo cho một khoản vay cụ thể
  /// Được gọi khi tạo mới hoặc cập nhật loan có bật reminder
  Future<void> scheduleLoanReminder(Loan loan) async {
    if (!loan.reminderEnabled || loan.dueDate == null || loan.reminderDays == null) {
      log('Loan ${loan.id} không có reminder hoặc không có dueDate');
      return;
    }

    if (!_isInitialized) {
      await initialize();
    }

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dueDate = DateTime(loan.dueDate!.year, loan.dueDate!.month, loan.dueDate!.day);
      final daysUntilDue = dueDate.difference(today).inDays;

      // Hủy các notification cũ của loan này trước
      await cancelLoanReminders(loan.id!);

      // Nếu đã quá hạn, không lên lịch thông báo mới
      if (daysUntilDue < 0) {
        log('Loan ${loan.id} đã quá hạn, không lên lịch reminder');
        return;
      }

      // Lên lịch thông báo cho mỗi ngày từ reminderDays đến ngày đến hạn
      for (int i = loan.reminderDays!; i >= 0; i--) {
        final notificationDate = dueDate.subtract(Duration(days: i));

        // Chỉ lên lịch cho các ngày trong tương lai
        if (notificationDate.isAfter(today)) {
          final scheduledDateTime = DateTime(
            notificationDate.year,
            notificationDate.month,
            notificationDate.day,
            9, // 9:00 AM
            0,
          );

          String title, body;
          if (i == 0) {
            // Ngày đến hạn
            title = 'Khoản ${loan.loanType == 'lend' ? 'cho vay' : 'đi vay'} đến hạn hôm nay!';
            body = '${loan.personName} - ${_formatAmount(loan.amount)} đến hạn thanh toán hôm nay.';
          } else if (i == 1) {
            // Ngày mai đến hạn
            title = 'Nhắc nhở: Khoản ${loan.loanType == 'lend' ? 'cho vay' : 'đi vay'} sắp đến hạn';
            body = '${loan.personName} - ${_formatAmount(loan.amount)} sẽ đến hạn vào ngày mai.';
          } else {
            // Còn nhiều ngày
            title = 'Nhắc nhở: Khoản ${loan.loanType == 'lend' ? 'cho vay' : 'đi vay'} sắp đến hạn';
            body = '${loan.personName} - ${_formatAmount(loan.amount)} còn $i ngày nữa đến hạn.';
          }

          // Sử dụng ID khác nhau cho mỗi ngày để tránh ghi đè
          final notificationId = loan.id! + (1000 * i);

          await scheduleNotification(
            id: notificationId,
            title: title,
            body: body,
            scheduledDate: scheduledDateTime,
            payload: 'loan_${loan.id}',
          );

          log('✅ Scheduled notification ID $notificationId for loan ${loan.id} at $scheduledDateTime ($i days before due)');
        }
      }

      // Nếu hôm nay đã trong khoảng thời gian nhắc nhở, gửi thông báo ngay
      if (daysUntilDue <= loan.reminderDays! && daysUntilDue >= 0) {
        await _createReminderForLoan(loan, daysUntilDue);
      }
    } catch (e) {
      log('Error scheduling loan reminder: $e');
    }
  }

  /// Hủy tất cả thông báo liên quan đến một loan
  Future<void> cancelLoanReminders(int loanId) async {
    // Hủy notification chính
    await cancelNotification(loanId);

    // Hủy tất cả các notification hàng ngày (0-30 ngày trước due date)
    for (int i = 0; i <= 30; i++) {
      await cancelNotification(loanId + (1000 * i));
    }

    // Hủy overdue notification
    await cancelNotification(loanId + 10000);

    log('Cancelled all notifications for loan $loanId');
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
      final today = DateTime(now.year, now.month, now.day);

      // Lấy tất cả khoản vay đang active và có bật nhắc nhở
      final loans = await dbHelper.getActiveLoansWithReminders();

      log('📋 Checking ${loans.length} active loans with reminders');

      for (final loan in loans) {
        if (loan.dueDate == null || loan.reminderDays == null) continue;

        final dueDate = DateTime(loan.dueDate!.year, loan.dueDate!.month, loan.dueDate!.day);
        final daysUntilDue = dueDate.difference(today).inDays;

        log('Checking loan ${loan.id} (${loan.personName}): $daysUntilDue days until due');

        // Kiểm tra nếu vẫn trong khoảng thời gian nhắc nhở
        if (daysUntilDue >= 0 && daysUntilDue <= loan.reminderDays!) {
          // Kiểm tra xem đã gửi thông báo hôm nay chưa
          final lastSent = loan.lastReminderSent;
          bool shouldSend = true;

          if (lastSent != null) {
            final lastSentDay = DateTime(lastSent.year, lastSent.month, lastSent.day);
            if (today.isAtSameMomentAs(lastSentDay)) {
              shouldSend = false;
              log('Already sent reminder today for loan ${loan.id}');
            }
          }

          if (shouldSend) {
            await _createReminderForLoan(loan, daysUntilDue);
          }
        }

        // Kiểm tra nếu đã quá hạn
        if (daysUntilDue < 0 && loan.status == 'active') {
          await _createOverdueNotification(loan);
          // Cập nhật trạng thái loan sang overdue
          await dbHelper.updateLoanStatus(loan.id!, 'overdue');
        }
      }

      log('✅ Finished checking loan reminders');
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
      final today = DateTime(now.year, now.month, now.day);
      final lastSentDay = DateTime(lastSent.year, lastSent.month, lastSent.day);

      // Nếu đã gửi thông báo hôm nay rồi, không gửi lại
      if (today.isAtSameMomentAs(lastSentDay)) {
        log('Already sent reminder today for loan ${loan.id}');
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
    } else if (daysUntilDue == 1) {
      type = 'reminder';
      title = 'Nhắc nhở: Khoản ${loan.loanType == 'lend' ? 'cho vay' : 'đi vay'} sắp đến hạn';
      body = '${loan.personName} - ${_formatAmount(loan.amount)} sẽ đến hạn vào ngày mai.';
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

    log('✅ Sent reminder notification for loan ${loan.id}: $daysUntilDue days until due');
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

  /// Đếm số khoản vay sắp đến hạn (dựa vào reminderDays của từng loan)
  Future<int> getUpcomingLoansCount() async {
    final dbHelper = DatabaseHelper();
    final now = DateTime.now();
    final loans = await dbHelper.getActiveLoansWithReminders();

    return loans.where((loan) {
      if (loan.dueDate == null || loan.reminderDays == null) return false;
      final daysUntilDue = loan.dueDate!.difference(now).inDays;
      // Đếm loan nếu:
      // - Còn thời gian đến hạn (>= 0)
      // - Đã vào khoảng thời gian nhắc nhở (<= reminderDays)
      // VD: dueDate = 11/11, reminderDays = 3, today = 9/11
      //     → daysUntilDue = 2, reminderDays = 3 → hiển thị badge
      return daysUntilDue >= 0 && daysUntilDue <= loan.reminderDays!;
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

