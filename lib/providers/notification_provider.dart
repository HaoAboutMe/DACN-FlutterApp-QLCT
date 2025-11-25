import 'package:flutter/material.dart';
import '../database/repositories/repositories.dart';
import '../models/notification_data.dart';
import '../services/notification_service.dart';

/// Provider quản lý trạng thái thông báo
class NotificationProvider extends ChangeNotifier {
  final NotificationRepository _notificationRepository = NotificationRepository();
  final LoanRepository _loanRepository = LoanRepository();
  final NotificationService _notificationService = NotificationService();

  List<NotificationData> _notifications = [];
  int _unreadCount = 0;
  int _upcomingLoansCount = 0;
  bool _isLoading = false;

  List<NotificationData> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  int get upcomingLoansCount => _upcomingLoansCount;
  bool get isLoading => _isLoading;

  /// Khởi tạo provider và load dữ liệu
  Future<void> initialize() async {
    await _notificationService.initialize();
    await loadNotifications();
    await updateBadgeCounts();
  }

  /// Load danh sách thông báo
  Future<void> loadNotifications() async {
    _isLoading = true;
    notifyListeners();

    try {
      _notifications = await _notificationRepository.getAllNotificationsPaginated(limit: 100);
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Cập nhật số lượng badge
  Future<void> updateBadgeCounts() async {
    try {
      _unreadCount = await _notificationService.getUnreadNotificationCount();
      _upcomingLoansCount = await _notificationService.getUpcomingLoansCount();
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating badge counts: $e');
    }
  }

  /// Kiểm tra và tạo thông báo mới
  Future<void> checkAndCreateReminders() async {
    try {
      await _notificationService.checkAndCreateLoanReminders();
      await loadNotifications();
      await updateBadgeCounts();
    } catch (e) {
      debugPrint('Error checking reminders: $e');
    }
  }

  /// Đánh dấu notification là đã đọc
  Future<void> markAsRead(int notificationId) async {
    try {
      await _notificationRepository.markNotificationAsRead(notificationId);

      // Cập nhật local state
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
      }

      await updateBadgeCounts();
      notifyListeners();
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  /// Đánh dấu tất cả là đã đọc
  Future<void> markAllAsRead() async {
    try {
      await _notificationRepository.markAllNotificationsAsRead();

      // Cập nhật local state
      _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();

      await updateBadgeCounts();
      notifyListeners();
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  /// Xóa một notification
  Future<void> deleteNotification(int notificationId) async {
    try {
      await _notificationRepository.deleteNotificationById(notificationId);
      _notifications.removeWhere((n) => n.id == notificationId);
      await updateBadgeCounts();
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  /// Xóa tất cả notifications
  Future<void> deleteAllNotifications() async {
    try {
      await _notificationRepository.deleteAllNotifications();
      _notifications.clear();
      await updateBadgeCounts();
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting all notifications: $e');
    }
  }

  /// Lấy notification chưa đọc
  List<NotificationData> get unreadNotifications {
    return _notifications.where((n) => !n.isRead).toList();
  }

  /// Lấy notification theo loại
  List<NotificationData> getNotificationsByType(String type) {
    return _notifications.where((n) => n.type == type).toList();
  }

  /// Xử lý khi loan được tạo hoặc cập nhật
  /// Lên lịch thông báo và cập nhật badge count ngay lập tức
  Future<void> onLoanCreatedOrUpdated(int loanId) async {
    try {
      debugPrint('🔔 NotificationProvider: Processing loan $loanId');

      // Lấy thông tin loan từ database
      final loan = await _loanRepository.getLoanById(loanId);
      if (loan == null) {
        debugPrint('⚠️ Loan $loanId not found');
        return;
      }

      // Nếu loan có bật reminder và có dueDate, lên lịch thông báo
      if (loan.reminderEnabled && loan.dueDate != null && loan.reminderDays != null) {
        debugPrint('📅 Scheduling reminder for loan ${loan.personName}');
        await _notificationService.scheduleLoanReminder(loan);
      } else {
        // Nếu tắt reminder hoặc không có dueDate, hủy các thông báo cũ
        debugPrint('🗑️ Cancelling reminders for loan ${loan.personName}');
        await _notificationService.cancelLoanReminders(loanId);
      }

      // Cập nhật badge count ngay lập tức
      await updateBadgeCounts();

      debugPrint('✅ NotificationProvider: Processed loan $loanId successfully');
    } catch (e) {
      debugPrint('❌ Error processing loan $loanId: $e');
    }
  }

  /// Xử lý khi loan bị xóa
  /// Hủy thông báo và cập nhật badge count ngay lập tức
  Future<void> onLoanDeleted(int loanId) async {
    try {
      debugPrint('🗑️ NotificationProvider: Processing loan deletion $loanId');

      // Hủy tất cả thông báo liên quan đến loan này
      await _notificationService.cancelLoanReminders(loanId);

      // Xóa các notification trong database liên quan đến loan này
      final notifications = await _notificationRepository.getNotificationsByLoanId(loanId);
      for (final notification in notifications) {
        if (notification.id != null) {
          await _notificationRepository.deleteNotificationById(notification.id!);
        }
      }

      // Reload notifications và cập nhật badge
      await loadNotifications();
      await updateBadgeCounts();

      debugPrint('✅ NotificationProvider: Deleted loan $loanId notifications');
    } catch (e) {
      debugPrint('❌ Error deleting loan $loanId notifications: $e');
    }
  }

  /// Xử lý khi loan được đánh dấu đã thanh toán
  /// Hủy thông báo và cập nhật badge count
  Future<void> onLoanPaid(int loanId) async {
    try {
      debugPrint('💰 NotificationProvider: Processing loan payment $loanId');

      // Hủy tất cả thông báo liên quan
      await _notificationService.cancelLoanReminders(loanId);

      // Cập nhật badge count
      await updateBadgeCounts();

      debugPrint('✅ NotificationProvider: Processed loan payment $loanId');
    } catch (e) {
      debugPrint('❌ Error processing loan payment $loanId: $e');
    }
  }
}

