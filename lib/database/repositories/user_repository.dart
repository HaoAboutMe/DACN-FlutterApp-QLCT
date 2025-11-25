import 'dart:developer';
import 'package:shared_preferences/shared_preferences.dart';
import '../database_helper.dart';
import '../../models/user.dart';

class UserRepository {
  static final UserRepository _instance = UserRepository._internal();
  factory UserRepository() => _instance;
  UserRepository._internal();

  final DatabaseHelper _db = DatabaseHelper();

  Future<int> insertUser(User user) async {
    try {
      final db = await _db.database;
      final id = await db.insert('users', user.toMap());
      log('Thêm user thành công với ID: $id');
      return id;
    } catch (e) {
      log('Lỗi thêm user: $e');
      rethrow;
    }
  }

  Future<int> updateUser(User user) async {
    try {
      final db = await _db.database;
      final count = await db.update(
        'users',
        user.toMap(),
        where: 'id = ?',
        whereArgs: [user.id],
      );
      log('Cập nhật user thành công');
      return count;
    } catch (e) {
      log('Lỗi cập nhật user: $e');
      rethrow;
    }
  }

  Future<int> deleteUser(int id) async {
    try {
      final db = await _db.database;
      final count = await db.delete(
        'users',
        where: 'id = ?',
        whereArgs: [id],
      );
      log('Xóa user thành công');
      return count;
    } catch (e) {
      log('Lỗi xóa user: $e');
      rethrow;
    }
  }

  Future<List<User>> getAllUsers() async {
    try {
      final db = await _db.database;
      final maps = await db.query('users');
      return List.generate(maps.length, (i) => User.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy danh sách users: $e');
      rethrow;
    }
  }

  Future<User?> getUserById(int id) async {
    try {
      final db = await _db.database;
      final maps = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty) {
        return User.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      log('Lỗi lấy user theo ID: $e');
      rethrow;
    }
  }

  Future<double> getCurrentBalance() async {
    try {
      final currentUserId = await getCurrentUserId();
      final user = await getUserById(currentUserId);
      return user?.balance ?? 0.0;
    } catch (e) {
      log('Error getting current balance: $e');
      return 0.0;
    }
  }

  Future<User?> getCurrentUser() async {
    try {
      final currentUserId = await getCurrentUserId();
      return await getUserById(currentUserId);
    } catch (e) {
      log('Error getting current user: $e');
      return null;
    }
  }

  Future<int> getCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('currentUserId') ?? 1;
      log('Current user ID: $userId');
      return userId;
    } catch (e) {
      log('Error getting current user ID: $e');
      return 1;
    }
  }

  Future<bool> updateUserBalanceAfterTransaction({
    int? userId,
    required double amount,
    required String transactionType,
  }) async {
    try {
      final db = await _db.database;
      final currentUserId = userId ?? await getCurrentUserId();

      await db.transaction((txn) async {
        final userMaps = await txn.query(
          'users',
          where: 'id = ?',
          whereArgs: [currentUserId],
        );

        if (userMaps.isEmpty) {
          throw Exception('Không tìm thấy người dùng với ID: $currentUserId');
        }

        final currentUser = User.fromMap(userMaps.first);
        double newBalance = currentUser.balance;

        log('Current user balance before update: ${currentUser.balance}');

        switch (transactionType) {
          case 'income':
          case 'debt_collected':
          case 'loan_received':
            newBalance += amount;
            log('Adding $amount to balance (type: $transactionType)');
            break;
          case 'expense':
          case 'loan_given':
          case 'debt_paid':
            newBalance -= amount;
            log('Subtracting $amount from balance (type: $transactionType)');
            break;
        }

        await txn.update(
          'users',
          {'balance': newBalance, 'updatedAt': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [currentUserId],
        );

        log('Cập nhật số dư user ID $currentUserId: ${currentUser.balance} -> $newBalance');
      });

      return true;
    } catch (e) {
      log('Lỗi cập nhật số dư user: $e');
      rethrow;
    }
  }
}

