import 'dart:developer';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import '../database/repositories/repositories.dart';
import '../models/loan.dart';
import '../models/notification_data.dart';

/// Callback cho AlarmManager - PHẢI là top-level function
@pragma('vm:entry-point')
void alarmCallback() async {
  try {
    final hour = DateTime.now().hour;
    if (hour != 9) {
      log("⏳ Bỏ qua callback vì không phải 9h sáng (giờ hiện tại: $hour)");
      return;
    }

    log('🔔 AlarmManager callback started');

    // Khởi tạo timezone
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

    // Khởi tạo notification plugin
    final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await notifications.initialize(initSettings);

    // Chạy check and create loan reminders
    await _backgroundCheckLoanReminders(notifications);

    log('✅ AlarmManager callback completed successfully');
  } catch (e) {
    log('❌ AlarmManager callback failed: $e');
  }
}

/// Background check loan reminders - được gọi từ AlarmManager
Future<void> _backgroundCheckLoanReminders(FlutterLocalNotificationsPlugin notifications) async {
  try {
    final loanRepo = LoanRepository();
    final notificationRepo = NotificationRepository();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final loans = await loanRepo.getActiveLoansWithReminders();
    log('📋 Background checking ${loans.length} active loans');

    for (final loan in loans) {
      if (loan.dueDate == null || loan.reminderDays == null) continue;

      final dueDate = DateTime(loan.dueDate!.year, loan.dueDate!.month, loan.dueDate!.day);
      final daysUntilDue = dueDate.difference(today).inDays;

      if (daysUntilDue >= 0 && daysUntilDue <= loan.reminderDays!) {
        final lastSent = loan.lastReminderSent;
        bool shouldSend = true;

        if (lastSent != null) {
          final lastSentDay = DateTime(lastSent.year, lastSent.month, lastSent.day);
          if (today.isAtSameMomentAs(lastSentDay)) {
            shouldSend = false;
          }
        }

        if (shouldSend) {
          await _sendReminderNotification(loan, daysUntilDue, notifications, loanRepo, notificationRepo);
        }
      }

      if (daysUntilDue < 0 && loan.status == 'active') {
        await _sendOverdueNotification(loan, notifications, loanRepo, notificationRepo);
        await loanRepo.updateLoanStatus(loan.id!, 'overdue');
      }
    }
  } catch (e) {
    log('Error in background check: $e');
  }
}

/// Gửi reminder notification từ background
Future<void> _sendReminderNotification(
  Loan loan,
  int daysUntilDue,
  FlutterLocalNotificationsPlugin notifications,
  LoanRepository loanRepo,
  NotificationRepository notificationRepo,
) async {
  final now = DateTime.now();

  String title, body, type;

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

  final notification = NotificationData(
    loanId: loan.id,
    type: type,
    title: title,
    body: body,
    sentAt: now,
    isRead: false,
  );

  await notificationRepo.insertNotification(notification);

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

  await notifications.show(loan.id!, title, body, details, payload: 'loan_${loan.id}');
  await loanRepo.updateLoanLastReminderSent(loan.id!, now);

  log('✅ Sent reminder for loan ${loan.id}');
}

/// Gửi overdue notification từ background
Future<void> _sendOverdueNotification(
  Loan loan,
  FlutterLocalNotificationsPlugin notifications,
  LoanRepository loanRepo,
  NotificationRepository notificationRepo,
) async {
  final now = DateTime.now();
  final daysOverdue = now.difference(loan.dueDate!).inDays;

  final existingNotifications = await notificationRepo.getNotificationsByLoanId(loan.id!);
  final hasOverdueNotification = existingNotifications.any(
    (n) => n.type == 'overdue' && n.sentAt.isAfter(loan.dueDate!),
  );

  if (hasOverdueNotification) return;

  final title = 'Khoản ${loan.loanType == 'lend' ? 'cho vay' : 'đi vay'} đã quá hạn!';
  final body = '${loan.personName} - ${_formatAmount(loan.amount)} đã quá hạn $daysOverdue ngày.';

  final notification = NotificationData(
    loanId: loan.id,
    type: 'overdue',
    title: title,
    body: body,
    sentAt: now,
    isRead: false,
  );

  await notificationRepo.insertNotification(notification);

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

  await notifications.show(
    loan.id! + 10000,
    title,
    body,
    details,
    payload: 'loan_${loan.id}',
  );

  log('✅ Sent overdue notification for loan ${loan.id}');
}

String _formatAmount(double amount) {
  if (amount >= 1000000) {
    return '${(amount / 1000000).toStringAsFixed(1)}tr';
  } else if (amount >= 1000) {
    return '${(amount / 1000).toStringAsFixed(0)}k';
  }
  return amount.toStringAsFixed(0);
}

/// Service quản lý thông báo local, database và AlarmManager
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  bool _alarmManagerInitialized = false;

  static const int _alarmId = 0;
  static const int _dailyCheckHour = 9; // 9:00 AM

  /// Khởi tạo notification service và AlarmManager
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Khởi tạo timezone
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

      // Cấu hình notification
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      await _requestPermissions();

      // Khởi tạo AlarmManager
      await _initializeAlarmManager();

      _isInitialized = true;
      log('NotificationService initialized successfully');
    } catch (e) {
      log('Error initializing NotificationService: $e');
    }
  }

  /// Khởi tạo AlarmManager với periodic task
  Future<void> _initializeAlarmManager() async {
    if (_alarmManagerInitialized) return;

    try {
      // Khởi tạo AlarmManager
      await AndroidAlarmManager.initialize();

      // Tính toán thời gian chạy lần đầu (9:00 AM hôm nay hoặc ngày mai)
      final now = DateTime.now();
      final todayAt9AM = DateTime(now.year, now.month, now.day, _dailyCheckHour, 0, 0);
      final startTime = now.isBefore(todayAt9AM) ? todayAt9AM : todayAt9AM.add(const Duration(days: 1));

      // Đăng ký periodic alarm - chạy mỗi ngày vào 9:00 AM
      await AndroidAlarmManager.periodic(
        const Duration(days: 1),
        _alarmId,
        alarmCallback,
        startAt: startTime,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );

      _alarmManagerInitialized = true;
      log('✅ AlarmManager initialized - daily task at 9:00 AM');
      log('⏰ First run: $startTime');
    } catch (e) {
      log('❌ Error initializing AlarmManager: $e');
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

      await cancelLoanReminders(loan.id!);

      if (daysUntilDue < 0) {
        log('Loan ${loan.id} đã quá hạn, không lên lịch reminder');
        return;
      }

      for (int i = loan.reminderDays!; i >= 0; i--) {
        final notificationDate = dueDate.subtract(Duration(days: i));

        if (notificationDate.isAfter(today)) {
          final scheduledDateTime = DateTime(
            notificationDate.year,
            notificationDate.month,
            notificationDate.day,
            9, 0,
          );

          String title, body;
          if (i == 0) {
            title = 'Khoản ${loan.loanType == 'lend' ? 'cho vay' : 'đi vay'} đến hạn hôm nay!';
            body = '${loan.personName} - ${_formatAmount(loan.amount)} đến hạn thanh toán hôm nay.';
          } else if (i == 1) {
            title = 'Nhắc nhở: Khoản ${loan.loanType == 'lend' ? 'cho vay' : 'đi vay'} sắp đến hạn';
            body = '${loan.personName} - ${_formatAmount(loan.amount)} sẽ đến hạn vào ngày mai.';
          } else {
            title = 'Nhắc nhở: Khoản ${loan.loanType == 'lend' ? 'cho vay' : 'đi vay'} sắp đến hạn';
            body = '${loan.personName} - ${_formatAmount(loan.amount)} còn $i ngày nữa đến hạn.';
          }

          final notificationId = loan.id! + (1000 * i);

          await scheduleNotification(
            id: notificationId,
            title: title,
            body: body,
            scheduledDate: scheduledDateTime,
            payload: 'loan_${loan.id}',
          );

          log('✅ Scheduled notification ID $notificationId for loan ${loan.id} at $scheduledDateTime');
        }
      }

      if (daysUntilDue <= loan.reminderDays! && daysUntilDue >= 0) {
        await _createReminderForLoan(loan, daysUntilDue);
      }
    } catch (e) {
      log('Error scheduling loan reminder: $e');
    }
  }

  /// Hủy tất cả thông báo liên quan đến một loan
  Future<void> cancelLoanReminders(int loanId) async {
    await cancelNotification(loanId);
    for (int i = 0; i <= 30; i++) {
      await cancelNotification(loanId + (1000 * i));
    }
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
  /// Được gọi khi app mở hoặc từ AlarmManager background
  Future<void> checkAndCreateLoanReminders() async {
    try {
      final loanRepo = LoanRepository();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final loans = await loanRepo.getActiveLoansWithReminders();

      log('📋 Checking ${loans.length} active loans with reminders');

      for (final loan in loans) {
        if (loan.dueDate == null || loan.reminderDays == null) continue;

        final dueDate = DateTime(loan.dueDate!.year, loan.dueDate!.month, loan.dueDate!.day);
        final daysUntilDue = dueDate.difference(today).inDays;

        log('Checking loan ${loan.id} (${loan.personName}): $daysUntilDue days until due');

        if (daysUntilDue >= 0 && daysUntilDue <= loan.reminderDays!) {
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

        if (daysUntilDue < 0 && loan.status == 'active') {
          await _createOverdueNotification(loan);
          await loanRepo.updateLoanStatus(loan.id!, 'overdue');
        }
      }

      log('✅ Finished checking loan reminders');
    } catch (e) {
      log('Error checking loan reminders: $e');
    }
  }

  /// Tạo thông báo nhắc nhở cho một khoản vay
  Future<void> _createReminderForLoan(Loan loan, int daysUntilDue) async {
    final loanRepo = LoanRepository();
    final notificationRepo = NotificationRepository();
    final now = DateTime.now();

    final lastSent = loan.lastReminderSent;
    if (lastSent != null) {
      final today = DateTime(now.year, now.month, now.day);
      final lastSentDay = DateTime(lastSent.year, lastSent.month, lastSent.day);

      if (today.isAtSameMomentAs(lastSentDay)) {
        log('Already sent reminder today for loan ${loan.id}');
        return;
      }
    }

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

    final notification = NotificationData(
      loanId: loan.id,
      type: type,
      title: title,
      body: body,
      sentAt: now,
      isRead: false,
    );

    await notificationRepo.insertNotification(notification);

    await showNotification(
      id: loan.id!,
      title: title,
      body: body,
      payload: 'loan_${loan.id}',
    );

    await loanRepo.updateLoanLastReminderSent(loan.id!, now);

    log('✅ Sent reminder notification for loan ${loan.id}: $daysUntilDue days until due');
  }

  /// Tạo thông báo khi khoản vay quá hạn
  Future<void> _createOverdueNotification(Loan loan) async {
    final loanRepo = LoanRepository();
    final notificationRepo = NotificationRepository();
    final now = DateTime.now();
    final daysOverdue = now.difference(loan.dueDate!).inDays;

    final existingNotifications = await notificationRepo.getNotificationsByLoanId(loan.id!);
    final hasOverdueNotification = existingNotifications.any(
      (n) => n.type == 'overdue' && n.sentAt.isAfter(loan.dueDate!),
    );

    if (hasOverdueNotification) return;

    final title = 'Khoản ${loan.loanType == 'lend' ? 'cho vay' : 'đi vay'} đã quá hạn!';
    final body = '${loan.personName} - ${_formatAmount(loan.amount)} đã quá hạn $daysOverdue ngày.';

    final notification = NotificationData(
      loanId: loan.id,
      type: 'overdue',
      title: title,
      body: body,
      sentAt: now,
      isRead: false,
    );

    await notificationRepo.insertNotification(notification);

    await showNotification(
      id: loan.id! + 10000,
      title: title,
      body: body,
      payload: 'loan_${loan.id}',
    );
  }

  /// Đếm số thông báo chưa đọc
  Future<int> getUnreadNotificationCount() async {
    final notificationRepo = NotificationRepository();
    return await notificationRepo.getUnreadNotificationCount();
  }

  /// Đếm số khoản vay sắp đến hạn
  Future<int> getUpcomingLoansCount() async {
    final loanRepo = LoanRepository();
    final now = DateTime.now();
    final loans = await loanRepo.getActiveLoansWithReminders();

    return loans.where((loan) {
      if (loan.dueDate == null || loan.reminderDays == null) return false;
      final daysUntilDue = loan.dueDate!.difference(now).inDays;
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

  /// Test AlarmManager ngay lập tức (dùng để test)
  Future<void> testAlarmManagerNow() async {
    try {
      final testTime = DateTime.now().add(const Duration(seconds: 10));

      await AndroidAlarmManager.oneShotAt(
        testTime,
        1, // Test alarm ID
        alarmCallback,
        exact: true,
        wakeup: true,
      );

      log('✅ Test alarm registered - will run at $testTime');
    } catch (e) {
      log('❌ Error registering test alarm: $e');
    }
  }

  /// Hủy alarm periodic
  Future<void> cancelPeriodicAlarm() async {
    try {
      await AndroidAlarmManager.cancel(_alarmId);
      _alarmManagerInitialized = false;
      log('✅ Cancelled periodic alarm');
    } catch (e) {
      log('❌ Error cancelling alarm: $e');
    }
  }
}

