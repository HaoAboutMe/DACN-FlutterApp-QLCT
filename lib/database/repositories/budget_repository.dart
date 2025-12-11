import 'dart:developer';
import '../database_helper.dart';
import '../../models/budget.dart';

class BudgetRepository {
  static final BudgetRepository _instance = BudgetRepository._internal();
  factory BudgetRepository() => _instance;
  BudgetRepository._internal();

  final DatabaseHelper _db = DatabaseHelper();

  Future<int> insertBudget(Budget budget) async {
    try {
      final db = await _db.database;
      final id = await db.insert('budgets', budget.toMap());
      log('Thêm budget thành công với ID: $id');
      return id;
    } catch (e) {
      log('Lỗi thêm budget: $e');
      rethrow;
    }
  }

  Future<int> updateBudget(Budget budget) async {
    try {
      final db = await _db.database;
      final count = await db.update(
        'budgets',
        budget.toMap(),
        where: 'id = ?',
        whereArgs: [budget.id],
      );
      log('Cập nhật budget thành công');
      return count;
    } catch (e) {
      log('Lỗi cập nhật budget: $e');
      rethrow;
    }
  }

  Future<int> deleteBudget(int id) async {
    try {
      final db = await _db.database;
      final count = await db.delete(
        'budgets',
        where: 'id = ?',
        whereArgs: [id],
      );
      log('Xóa budget thành công');
      return count;
    } catch (e) {
      log('Lỗi xóa budget: $e');
      rethrow;
    }
  }

  Future<List<Budget>> getAllBudgets() async {
    try {
      final db = await _db.database;
      final maps = await db.query(
        'budgets',
        orderBy: 'start_date DESC, id DESC',
      );
      return List.generate(maps.length, (i) => Budget.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy danh sách budgets: $e');
      rethrow;
    }
  }

  Future<Budget?> getBudgetById(int id) async {
    try {
      final db = await _db.database;
      final maps = await db.query(
        'budgets',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty) {
        return Budget.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      log('Lỗi lấy budget theo ID: $e');
      rethrow;
    }
  }

  Future<List<Budget>> getBudgetsByCategory(int categoryId) async {
    try {
      final db = await _db.database;
      final maps = await db.query(
        'budgets',
        where: 'category_id = ?',
        whereArgs: [categoryId],
        orderBy: 'start_date DESC',
      );
      return List.generate(maps.length, (i) => Budget.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy budgets theo category: $e');
      rethrow;
    }
  }

  Future<List<Budget>> getActiveBudgets() async {
    try {
      final db = await _db.database;
      final now = DateTime.now().toIso8601String();

      final maps = await db.query(
        'budgets',
        where: 'start_date <= ? AND end_date >= ?',
        whereArgs: [now, now],
        orderBy: 'amount DESC',
      );
      return List.generate(maps.length, (i) => Budget.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy budgets đang hoạt động: $e');
      rethrow;
    }
  }

  Future<Budget?> getActiveBudgetByCategory(int categoryId) async {
    try {
      final db = await _db.database;
      final now = DateTime.now().toIso8601String();

      final maps = await db.query(
        'budgets',
        where: 'category_id = ? AND start_date <= ? AND end_date >= ?',
        whereArgs: [categoryId, now, now],
        orderBy: 'start_date DESC',
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return Budget.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      log('Lỗi lấy budget đang hoạt động theo category: $e');
      rethrow;
    }
  }

  Future<Budget?> getActiveOverallBudget() async {
    try {
      final db = await _db.database;
      final now = DateTime.now().toIso8601String();

      final maps = await db.query(
        'budgets',
        where: 'category_id IS NULL AND start_date <= ? AND end_date >= ?',
        whereArgs: [now, now],
        orderBy: 'start_date DESC',
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return Budget.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      log('Lỗi lấy ngân sách tổng đang hoạt động: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getOverallBudgetProgress() async {
    try {
      // Get the latest overall budget (active or expired)
      final db = await _db.database;
      final maps = await db.query(
        'budgets',
        where: 'category_id IS NULL',
        orderBy: 'end_date DESC, start_date DESC',
        limit: 1,
      );

      if (maps.isEmpty) return null;

      final overallBudget = Budget.fromMap(maps.first);
      final now = DateTime.now();
      final isExpired = now.isAfter(overallBudget.endDate);

      final totalSpent = await _getTotalExpenseInPeriod(
        overallBudget.startDate,
        overallBudget.endDate,
      );

      final progressPercentage = overallBudget.amount > 0
          ? (totalSpent / overallBudget.amount) * 100
          : 0.0;

      return {
        'budgetId': overallBudget.id,
        'budgetAmount': overallBudget.amount,
        'totalSpent': totalSpent,
        'progressPercentage': progressPercentage,
        'remainingAmount': overallBudget.amount - totalSpent,
        'isOverBudget': totalSpent > overallBudget.amount,
        'isExpired': isExpired,
        'startDate': overallBudget.startDate.toIso8601String(),
        'endDate': overallBudget.endDate.toIso8601String(),
      };
    } catch (e) {
      log('Lỗi lấy tiến độ ngân sách tổng: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllOverallBudgetsProgress() async {
    try {
      final db = await _db.database;
      final maps = await db.query(
        'budgets',
        where: 'category_id IS NULL',
        orderBy: 'end_date DESC, start_date DESC',
      );

      if (maps.isEmpty) return [];

      final now = DateTime.now();
      final List<Map<String, dynamic>> results = [];

      for (final map in maps) {
        final budget = Budget.fromMap(map);
        final isExpired = now.isAfter(budget.endDate);

        final totalSpent = await _getTotalExpenseInPeriod(
          budget.startDate,
          budget.endDate,
        );

        final progressPercentage = budget.amount > 0
            ? (totalSpent / budget.amount) * 100
            : 0.0;

        results.add({
          'budgetId': budget.id,
          'budgetAmount': budget.amount,
          'totalSpent': totalSpent,
          'progressPercentage': progressPercentage,
          'remainingAmount': budget.amount - totalSpent,
          'isOverBudget': totalSpent > budget.amount,
          'isExpired': isExpired,
          'startDate': budget.startDate.toIso8601String(),
          'endDate': budget.endDate.toIso8601String(),
        });
      }

      return results;
    } catch (e) {
      log('Lỗi lấy tất cả tiến độ ngân sách tổng: $e');
      rethrow;
    }
  }

  Future<double> getCategoryExpenseInBudgetPeriod(
    int categoryId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final db = await _db.database;
      final result = await db.rawQuery('''
        SELECT SUM(amount) as total
        FROM transactions
        WHERE type = 'expense'
        AND categoryId = ?
        AND date BETWEEN ? AND ?
      ''', [categoryId, startDate.toIso8601String(), endDate.toIso8601String()]);

      return (result.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      log('Lỗi tính chi tiêu theo category trong budget period: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getBudgetProgress() async {
    try {
      final db = await _db.database;
      final now = DateTime.now().toIso8601String();

      final result = await db.rawQuery('''
        SELECT 
          b.id as budgetId,
          b.amount as budgetAmount,
          b.start_date as startDate,
          b.end_date as endDate,
          c.id as categoryId,
          c.name as categoryName,
          c.icon as categoryIcon,
          COALESCE(SUM(t.amount), 0) as totalSpent
        FROM budgets b
        INNER JOIN categories c ON b.category_id = c.id
        LEFT JOIN transactions t ON t.categoryId = c.id 
          AND t.type = 'expense'
          AND t.date BETWEEN b.start_date AND b.end_date
        WHERE b.category_id IS NOT NULL
        GROUP BY b.id, b.amount, b.start_date, b.end_date, 
                 c.id, c.name, c.icon
        ORDER BY 
          CASE WHEN b.end_date >= ? THEN 0 ELSE 1 END,
          (COALESCE(SUM(t.amount), 0) / b.amount) DESC,
          b.end_date DESC
      ''', [now]);

      return result.map((row) {
        final budgetAmount = (row['budgetAmount'] as num).toDouble();
        final totalSpent = (row['totalSpent'] as num).toDouble();
        final progressPercentage = budgetAmount > 0 ? (totalSpent / budgetAmount) * 100 : 0.0;
        final endDate = DateTime.parse(row['endDate'] as String);
        final isExpired = DateTime.now().isAfter(endDate);

        return {
          ...row,
          'progressPercentage': progressPercentage,
          'remainingAmount': budgetAmount - totalSpent,
          'isOverBudget': totalSpent > budgetAmount,
          'isExpired': isExpired,
        };
      }).toList();
    } catch (e) {
      log('Lỗi lấy báo cáo tiến độ ngân sách: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getBudgetProgressByCategory(int categoryId) async {
    try {
      final db = await _db.database;
      final now = DateTime.now().toIso8601String();

      final result = await db.rawQuery('''
        SELECT 
          b.id as budgetId,
          b.amount as budgetAmount,
          b.start_date as startDate,
          b.end_date as endDate,
          c.id as categoryId,
          c.name as categoryName,
          c.icon as categoryIcon,
          COALESCE(SUM(t.amount), 0) as totalSpent
        FROM budgets b
        INNER JOIN categories c ON b.category_id = c.id
        LEFT JOIN transactions t ON t.categoryId = c.id 
          AND t.type = 'expense'
          AND t.date BETWEEN b.start_date AND b.end_date
        WHERE c.id = ?
          AND b.start_date <= ? AND b.end_date >= ?
        GROUP BY b.id, b.amount, b.start_date, b.end_date, 
                 c.id, c.name, c.icon
        ORDER BY b.start_date DESC
        LIMIT 1
      ''', [categoryId, now, now]);

      if (result.isEmpty) return null;

      final row = result.first;
      final budgetAmount = (row['budgetAmount'] as num).toDouble();
      final totalSpent = (row['totalSpent'] as num).toDouble();
      final progressPercentage = budgetAmount > 0 ? (totalSpent / budgetAmount) * 100 : 0.0;

      return {
        ...row,
        'progressPercentage': progressPercentage,
        'remainingAmount': budgetAmount - totalSpent,
        'isOverBudget': totalSpent > budgetAmount,
      };
    } catch (e) {
      log('Lỗi lấy tiến độ ngân sách theo category: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getOverBudgetCategories() async {
    try {
      final progressList = await getBudgetProgress();
      return progressList.where((item) => item['isOverBudget'] == true).toList();
    } catch (e) {
      log('Lỗi lấy danh sách categories vượt ngân sách: $e');
      rethrow;
    }
  }

  Future<double> getTotalActiveBudget() async {
    try {
      final db = await _db.database;
      final now = DateTime.now().toIso8601String();

      final result = await db.rawQuery('''
        SELECT SUM(amount) as total
        FROM budgets
        WHERE start_date <= ? AND end_date >= ?
      ''', [now, now]);

      return (result.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      log('Lỗi tính tổng ngân sách đang hoạt động: $e');
      rethrow;
    }
  }

  Future<double> _getTotalExpenseInPeriod(DateTime startDate, DateTime endDate) async {
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
}

