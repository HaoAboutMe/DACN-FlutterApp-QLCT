import 'dart:developer';
import '../database_helper.dart';
import '../../models/transaction.dart' as transaction_model;

class TransactionRepository {
  static final TransactionRepository _instance = TransactionRepository._internal();
  factory TransactionRepository() => _instance;
  TransactionRepository._internal();

  final DatabaseHelper _db = DatabaseHelper();

  Future<int> insertTransaction(transaction_model.Transaction transaction) async {
    try {
      final db = await _db.database;
      final id = await db.insert('transactions', transaction.toMap());
      log('Thêm transaction thành công với ID: $id');
      return id;
    } catch (e) {
      log('Lỗi thêm transaction: $e');
      rethrow;
    }
  }

  Future<int> updateTransaction(transaction_model.Transaction transaction) async {
    try {
      final db = await _db.database;
      final count = await db.update(
        'transactions',
        transaction.toMap(),
        where: 'id = ?',
        whereArgs: [transaction.id],
      );
      log('Cập nhật transaction thành công');
      return count;
    } catch (e) {
      log('Lỗi cập nhật transaction: $e');
      rethrow;
    }
  }

  Future<int> deleteTransaction(int id) async {
    try {
      final db = await _db.database;
      final count = await db.delete(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
      );
      log('Xóa transaction thành công');
      return count;
    } catch (e) {
      log('Lỗi xóa transaction: $e');
      rethrow;
    }
  }

  Future<List<transaction_model.Transaction>> getAllTransactions() async {
    try {
      final db = await _db.database;
      final maps = await db.query(
        'transactions',
        orderBy: 'date DESC, id DESC',
      );
      return List.generate(maps.length, (i) => transaction_model.Transaction.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy danh sách transactions: $e');
      rethrow;
    }
  }

  Future<List<transaction_model.Transaction>> getRecentTransactions({int limit = 10}) async {
    try {
      final db = await _db.database;
      final maps = await db.query(
        'transactions',
        orderBy: 'date DESC, id DESC',
        limit: limit,
      );
      return List.generate(maps.length, (i) => transaction_model.Transaction.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy danh sách giao dịch gần đây: $e');
      rethrow;
    }
  }

  Future<transaction_model.Transaction?> getTransactionById(int id) async {
    try {
      final db = await _db.database;
      final maps = await db.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty) {
        return transaction_model.Transaction.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      log('Lỗi lấy transaction theo ID: $e');
      rethrow;
    }
  }

  Future<List<transaction_model.Transaction>> getTransactionsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final db = await _db.database;
      final maps = await db.query(
        'transactions',
        where: 'date BETWEEN ? AND ?',
        whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
        orderBy: 'date DESC, id DESC',
      );
      return List.generate(maps.length, (i) => transaction_model.Transaction.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy transactions theo khoảng thời gian: $e');
      rethrow;
    }
  }

  Future<List<transaction_model.Transaction>> getTransactionsByType(String type) async {
    try {
      final db = await _db.database;
      final maps = await db.query(
        'transactions',
        where: 'type = ?',
        whereArgs: [type],
        orderBy: 'date DESC, id DESC',
      );
      return List.generate(maps.length, (i) => transaction_model.Transaction.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy transactions theo type: $e');
      rethrow;
    }
  }

  Future<List<transaction_model.Transaction>> getTransactionsByLoanId(int loanId) async {
    try {
      final db = await _db.database;
      final maps = await db.query(
        'transactions',
        where: 'loanId = ?',
        whereArgs: [loanId],
        orderBy: 'date DESC, id DESC',
      );
      return List.generate(maps.length, (i) => transaction_model.Transaction.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy transactions theo loanId: $e');
      rethrow;
    }
  }

  Future<double> getTotalIncomeInPeriod(DateTime startDate, DateTime endDate) async {
    try {
      final db = await _db.database;
      final result = await db.rawQuery('''
        SELECT SUM(amount) as total
        FROM transactions
        WHERE type IN ('income', 'debt_collected', 'loan_received')
        AND date BETWEEN ? AND ?
      ''', [startDate.toIso8601String(), endDate.toIso8601String()]);

      return (result.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      log('Lỗi tính tổng thu nhập: $e');
      rethrow;
    }
  }

  Future<double> getTotalExpenseInPeriod(DateTime startDate, DateTime endDate) async {
    try {
      final db = await _db.database;
      final result = await db.rawQuery('''
        SELECT SUM(amount) as total
        FROM transactions
        WHERE type IN ('expense', 'loan_given', 'debt_paid')
        AND date BETWEEN ? AND ?
      ''', [startDate.toIso8601String(), endDate.toIso8601String()]);

      return (result.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      log('Lỗi tính tổng chi tiêu: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getExpenseReportByCategory(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final db = await _db.database;
      final result = await db.rawQuery('''
        SELECT
          c.name as categoryName,
          c.icon as categoryIcon,
          SUM(t.amount) as totalAmount,
          COUNT(t.id) as transactionCount
        FROM transactions t
        INNER JOIN categories c ON t.categoryId = c.id
        WHERE t.type = 'expense'
        AND t.date BETWEEN ? AND ?
        GROUP BY c.id, c.name, c.icon
        ORDER BY totalAmount DESC
      ''', [startDate.toIso8601String(), endDate.toIso8601String()]);

      return result;
    } catch (e) {
      log('Lỗi lấy báo cáo chi tiêu theo danh mục: $e');
      rethrow;
    }
  }

  Future<double> getTotalExpenseThisMonth() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      return await getTotalExpenseInPeriod(startOfMonth, endOfMonth);
    } catch (e) {
      log('Lỗi tính tổng chi tiêu tháng hiện tại: $e');
      rethrow;
    }
  }

  Future<Map<String, double>> getMonthlySummary(DateTime month) async {
    try {
      final startOfMonth = DateTime(month.year, month.month, 1);
      final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      final totalIncome = await getTotalIncomeInPeriod(startOfMonth, endOfMonth);
      final totalExpense = await getTotalExpenseInPeriod(startOfMonth, endOfMonth);

      return {
        'income': totalIncome,
        'expense': totalExpense,
        'balance': totalIncome - totalExpense,
      };
    } catch (e) {
      log('Lỗi lấy tổng kết tháng: $e');
      rethrow;
    }
  }
}

