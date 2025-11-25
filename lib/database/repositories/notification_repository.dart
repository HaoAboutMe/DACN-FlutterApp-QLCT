import 'dart:developer';
import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../../models/notification_data.dart';

class NotificationRepository {
  static final NotificationRepository _instance = NotificationRepository._internal();
  factory NotificationRepository() => _instance;
  NotificationRepository._internal();

  final DatabaseHelper _db = DatabaseHelper();

  Future<int> insertNotification(NotificationData notification) async {
    try {
      final db = await _db.database;
      final id = await db.insert('notifications', notification.toMap());
      log('Thêm notification thành công với ID: $id');
      return id;
    } catch (e) {
      log('Lỗi thêm notification: $e');
      rethrow;
    }
  }

  Future<int> updateNotification(NotificationData notification) async {
    try {
      final db = await _db.database;
      final count = await db.update(
        'notifications',
        notification.toMap(),
        where: 'id = ?',
        whereArgs: [notification.id],
      );
      log('Cập nhật notification thành công');
      return count;
    } catch (e) {
      log('Lỗi cập nhật notification: $e');
      rethrow;
    }
  }

  Future<int> deleteNotification(int id) async {
    try {
      final db = await _db.database;
      final count = await db.delete(
        'notifications',
        where: 'id = ?',
        whereArgs: [id],
      );
      log('Xóa notification thành công');
      return count;
    } catch (e) {
      log('Lỗi xóa notification: $e');
      rethrow;
    }
  }

  Future<List<NotificationData>> getAllNotifications() async {
    try {
      final db = await _db.database;
      final maps = await db.query(
        'notifications',
        orderBy: 'sentAt DESC, id DESC',
      );
      return List.generate(maps.length, (i) => NotificationData.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy danh sách notifications: $e');
      rethrow;
    }
  }

  Future<List<NotificationData>> getUnreadNotifications() async {
    try {
      final db = await _db.database;
      final maps = await db.query(
        'notifications',
        where: 'isRead = ?',
        whereArgs: [0],
        orderBy: 'sentAt DESC',
      );
      return List.generate(maps.length, (i) => NotificationData.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy notifications chưa đọc: $e');
      rethrow;
    }
  }

  Future<int> markAllNotificationsAsRead() async {
    try {
      final db = await _db.database;
      final count = await db.update(
        'notifications',
        {'isRead': 1},
        where: 'isRead = ?',
        whereArgs: [0],
      );
      log('Đánh dấu tất cả notifications đã đọc');
      return count;
    } catch (e) {
      log('Lỗi đánh dấu notifications đã đọc: $e');
      rethrow;
    }
  }

  Future<List<NotificationData>> getNotificationsByLoanId(int loanId) async {
    try {
      final db = await _db.database;
      final maps = await db.query(
        'notifications',
        where: 'loanId = ?',
        whereArgs: [loanId],
        orderBy: 'sentAt DESC',
      );
      return List.generate(maps.length, (i) => NotificationData.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy notifications theo loanId: $e');
      rethrow;
    }
  }

  Future<int> getUnreadNotificationCount() async {
    try {
      final db = await _db.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM notifications WHERE isRead = 0'
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      log('Lỗi đếm notifications chưa đọc: $e');
      rethrow;
    }
  }

  Future<List<NotificationData>> getAllNotificationsPaginated({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final db = await _db.database;
      final maps = await db.query(
        'notifications',
        orderBy: 'sentAt DESC',
        limit: limit,
        offset: offset,
      );
      return List.generate(maps.length, (i) => NotificationData.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy danh sách notifications: $e');
      rethrow;
    }
  }

  Future<int> deleteAllNotifications() async {
    try {
      final db = await _db.database;
      final count = await db.delete('notifications');
      log('Đã xóa tất cả $count notifications');
      return count;
    } catch (e) {
      log('Lỗi xóa tất cả notifications: $e');
      rethrow;
    }
  }

  Future<int> deleteNotificationById(int id) async {
    try {
      final db = await _db.database;
      final count = await db.delete(
        'notifications',
        where: 'id = ?',
        whereArgs: [id],
      );
      log('Đã xóa notification ID $id');
      return count;
    } catch (e) {
      log('Lỗi xóa notification: $e');
      rethrow;
    }
  }

  Future<int> markNotificationAsRead(int id) async {
    try {
      final db = await _db.database;
      final count = await db.update(
        'notifications',
        {'isRead': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
      log('Đánh dấu notification $id là đã đọc');
      return count;
    } catch (e) {
      log('Lỗi đánh dấu notification đã đọc: $e');
      rethrow;
    }
  }
}

