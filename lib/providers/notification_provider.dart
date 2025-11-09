import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/notification_data.dart';
import '../services/notification_service.dart';

/// Provider quản lý trạng thái thông báo
class NotificationProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
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
      _notifications = await _dbHelper.getAllNotificationsPaginated(limit: 100);
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
      await _dbHelper.markNotificationAsRead(notificationId);

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
      await _dbHelper.markAllNotificationsAsRead();

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
      await _dbHelper.deleteNotificationById(notificationId);
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
      await _dbHelper.deleteAllNotifications();
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
}

