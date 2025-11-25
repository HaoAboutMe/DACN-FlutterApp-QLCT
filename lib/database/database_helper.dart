import 'dart:async';
import 'dart:developer';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🏗️ ARCHITECTURE NOTE:
/// DatabaseHelper đã được refactor theo Clean Architecture - Repository Pattern
///
/// DatabaseHelper chỉ chứa:
/// ✅ Singleton instance
/// ✅ Database initialization & migration
/// ✅ Generic database operations (insert, update, delete, query)
///
/// Tất cả CRUD đặc thù đã được tách sang Repositories:
/// - CategoryRepository: Quản lý Categories
/// - TransactionRepository: Quản lý Transactions
/// - LoanRepository: Quản lý Loans
/// - BudgetRepository: Quản lý Budgets
/// - NotificationRepository: Quản lý Notifications
/// - UserRepository: Quản lý Users
///
/// Xem: lib/database/repositories/

/// Lớp DatabaseHelper quản lý cơ sở dữ liệu SQLite
/// Sử dụng singleton pattern để đảm bảo chỉ có một instance duy nhất
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  // Thông tin database
  static const String _databaseName = 'expense_tracker.db';
  static const int _databaseVersion = 4;

  // Tên các bảng
  static const String _tableUsers = 'users';
  static const String _tableCategories = 'categories';
  static const String _tableTransactions = 'transactions';
  static const String _tableLoans = 'loans';
  static const String _tableNotifications = 'notifications';
  static const String _tableBudgets = 'budgets';

  // Cột của bảng users
  static const String _colUserId = 'id';
  static const String _colUserName = 'name';
  static const String _colUserBalance = 'balance';
  static const String _colUserCreatedAt = 'createdAt';
  static const String _colUserUpdatedAt = 'updatedAt';

  // Cột của bảng categories
  static const String _colCategoryId = 'id';
  static const String _colCategoryName = 'name';
  static const String _colCategoryIcon = 'icon';
  static const String _colCategoryType = 'type';
  static const String _colCategoryBudget = 'budget';
  static const String _colCategoryCreatedAt = 'createdAt';

  // Cột của bảng transactions
  static const String _colTransactionId = 'id';
  static const String _colTransactionAmount = 'amount';
  static const String _colTransactionDescription = 'description';
  static const String _colTransactionDate = 'date';
  static const String _colTransactionCategoryId = 'categoryId';
  static const String _colTransactionLoanId = 'loanId';
  static const String _colTransactionType = 'type';
  static const String _colTransactionCreatedAt = 'createdAt';
  static const String _colTransactionUpdatedAt = 'updatedAt';

  // Cột của bảng loans
  static const String _colLoanId = 'id';
  static const String _colLoanPersonName = 'personName';
  static const String _colLoanPersonPhone = 'personPhone';
  static const String _colLoanAmount = 'amount';
  static const String _colLoanType = 'loanType';
  static const String _colLoanDate = 'loanDate';
  static const String _colLoanDueDate = 'dueDate';
  static const String _colLoanStatus = 'status';
  static const String _colLoanDescription = 'description';
  static const String _colLoanPaidDate = 'paidDate';
  static const String _colLoanReminderEnabled = 'reminderEnabled';
  static const String _colLoanReminderDays = 'reminderDays';
  static const String _colLoanLastReminderSent = 'lastReminderSent';
  static const String _colLoanIsOldDebt = 'isOldDebt';
  static const String _colLoanCreatedAt = 'createdAt';
  static const String _colLoanUpdatedAt = 'updatedAt';

  // Cột của bảng notifications
  static const String _colNotificationId = 'id';
  static const String _colNotificationLoanId = 'loanId';
  static const String _colNotificationType = 'type';
  static const String _colNotificationTitle = 'title';
  static const String _colNotificationBody = 'body';
  static const String _colNotificationSentAt = 'sentAt';
  static const String _colNotificationIsRead = 'isRead';

  // Cột của bảng budgets
  static const String _colBudgetId = 'id';
  static const String _colBudgetAmount = 'amount';
  static const String _colBudgetCategoryId = 'category_id';
  static const String _colBudgetStartDate = 'start_date';
  static const String _colBudgetEndDate = 'end_date';
  static const String _colBudgetCreatedAt = 'created_at';

  /// Getter để lấy instance database
  /// Tạo database mới nếu chưa tồn tại
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Khởi tạo database
  Future<Database> _initDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, _databaseName);

      log('Đường dẫn database: $path');

      return await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _createDatabase,
        onUpgrade: _upgradeDatabase,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
      );
    } catch (e) {
      log('Lỗi khởi tạo database: $e');
      rethrow;
    }
  }

  /// Tạo các bảng trong database
  Future<void> _createDatabase(Database db, int version) async {
    try {
      // Tạo bảng users
      await db.execute('''
        CREATE TABLE $_tableUsers (
          $_colUserId INTEGER PRIMARY KEY AUTOINCREMENT,
          $_colUserName TEXT NOT NULL,
          $_colUserBalance REAL NOT NULL DEFAULT 0,
          $_colUserCreatedAt TEXT NOT NULL,
          $_colUserUpdatedAt TEXT NOT NULL
        )
      ''');

      // Tạo bảng categories
      await db.execute('''
        CREATE TABLE $_tableCategories (
          $_colCategoryId INTEGER PRIMARY KEY AUTOINCREMENT,
          $_colCategoryName TEXT NOT NULL,
          $_colCategoryIcon TEXT NOT NULL,
          $_colCategoryType TEXT NOT NULL CHECK ($_colCategoryType IN ('income', 'expense')),
          $_colCategoryBudget REAL DEFAULT 0,
          $_colCategoryCreatedAt TEXT NOT NULL,
          UNIQUE($_colCategoryName, $_colCategoryType)
        )
      ''');

      // Tạo bảng loans
      await db.execute('''
        CREATE TABLE $_tableLoans (
          $_colLoanId INTEGER PRIMARY KEY AUTOINCREMENT,
          $_colLoanPersonName TEXT NOT NULL,
          $_colLoanPersonPhone TEXT,
          $_colLoanAmount REAL NOT NULL CHECK ($_colLoanAmount > 0),
          $_colLoanType TEXT NOT NULL CHECK ($_colLoanType IN ('lend', 'borrow')),
          $_colLoanDate TEXT NOT NULL,
          $_colLoanDueDate TEXT,
          $_colLoanStatus TEXT NOT NULL DEFAULT 'active' CHECK ($_colLoanStatus IN ('active', 'paid', 'overdue')),
          $_colLoanDescription TEXT,
          $_colLoanPaidDate TEXT,
          $_colLoanReminderEnabled INTEGER NOT NULL DEFAULT 0,
          $_colLoanReminderDays INTEGER,
          $_colLoanLastReminderSent TEXT,
          $_colLoanIsOldDebt INTEGER NOT NULL DEFAULT 0 CHECK ($_colLoanIsOldDebt IN (0, 1)),
          $_colLoanCreatedAt TEXT NOT NULL,
          $_colLoanUpdatedAt TEXT NOT NULL
        )
      ''');

      // Tạo bảng transactions
      await db.execute('''
        CREATE TABLE $_tableTransactions (
          $_colTransactionId INTEGER PRIMARY KEY AUTOINCREMENT,
          $_colTransactionAmount REAL NOT NULL CHECK ($_colTransactionAmount > 0),
          $_colTransactionDescription TEXT NOT NULL,
          $_colTransactionDate TEXT NOT NULL,
          $_colTransactionCategoryId INTEGER,
          $_colTransactionLoanId INTEGER,
          $_colTransactionType TEXT NOT NULL CHECK ($_colTransactionType IN ('income', 'expense', 'loan_given', 'loan_received', 'debt_paid', 'debt_collected')),
          $_colTransactionCreatedAt TEXT NOT NULL,
          $_colTransactionUpdatedAt TEXT NOT NULL,
          
          CHECK (
            ($_colTransactionCategoryId IS NOT NULL AND $_colTransactionLoanId IS NULL) OR
            ($_colTransactionCategoryId IS NULL AND $_colTransactionLoanId IS NOT NULL)
          ),
          
          FOREIGN KEY ($_colTransactionCategoryId) REFERENCES $_tableCategories ($_colCategoryId) ON DELETE SET NULL,
          FOREIGN KEY ($_colTransactionLoanId) REFERENCES $_tableLoans ($_colLoanId) ON DELETE CASCADE
        )
      ''');

      // Tạo bảng notifications
      await db.execute('''
        CREATE TABLE $_tableNotifications (
          $_colNotificationId INTEGER PRIMARY KEY AUTOINCREMENT,
          $_colNotificationLoanId INTEGER,
          $_colNotificationType TEXT NOT NULL,
          $_colNotificationTitle TEXT NOT NULL,
          $_colNotificationBody TEXT NOT NULL,
          $_colNotificationSentAt TEXT NOT NULL,
          $_colNotificationIsRead INTEGER NOT NULL DEFAULT 0,
          
          FOREIGN KEY ($_colNotificationLoanId) REFERENCES $_tableLoans ($_colLoanId) ON DELETE CASCADE
        )
      ''');

      // Tạo bảng budgets
      await db.execute('''
        CREATE TABLE $_tableBudgets (
          $_colBudgetId INTEGER PRIMARY KEY AUTOINCREMENT,
          $_colBudgetAmount REAL NOT NULL CHECK ($_colBudgetAmount >= 0),
          $_colBudgetCategoryId INTEGER,
          $_colBudgetStartDate TEXT NOT NULL,
          $_colBudgetEndDate TEXT NOT NULL,
          $_colBudgetCreatedAt TEXT NOT NULL,
          
          FOREIGN KEY ($_colBudgetCategoryId) REFERENCES $_tableCategories ($_colCategoryId) ON DELETE CASCADE
        )
      ''');

      // Tạo các index
      await _createIndexes(db);

      log('Tạo database thành công');
    } catch (e) {
      log('Lỗi tạo database: $e');
      rethrow;
    }
  }

  /// Tạo các index để tối ưu hiệu suất truy vấn
  Future<void> _createIndexes(Database db) async {
    try {
      await db.execute('''
        CREATE INDEX idx_transactions_date_type_category 
        ON $_tableTransactions ($_colTransactionDate, $_colTransactionType, $_colTransactionCategoryId)
      ''');

      await db.execute('''
        CREATE INDEX idx_transactions_loan_id 
        ON $_tableTransactions ($_colTransactionLoanId)
      ''');

      await db.execute('''
        CREATE INDEX idx_loans_status_due_date_name 
        ON $_tableLoans ($_colLoanStatus, $_colLoanDueDate, $_colLoanPersonName)
      ''');

      await db.execute('''
        CREATE INDEX idx_notifications_loan_id_sent_at 
        ON $_tableNotifications ($_colNotificationLoanId, $_colNotificationSentAt)
      ''');

      await db.execute('''
        CREATE INDEX idx_budgets_category_id 
        ON $_tableBudgets ($_colBudgetCategoryId)
      ''');

      log('Tạo indexes thành công');
    } catch (e) {
      log('Lỗi tạo indexes: $e');
      rethrow;
    }
  }

  /// Nâng cấp database khi có phiên bản mới
  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    log('Nâng cấp database từ phiên bản $oldVersion lên $newVersion');

    try {
      if (oldVersion < 2) {
        await db.execute('''
          ALTER TABLE $_tableLoans 
          ADD COLUMN $_colLoanIsOldDebt INTEGER NOT NULL DEFAULT 0 CHECK ($_colLoanIsOldDebt IN (0, 1))
        ''');
        log('Đã thêm cột isOldDebt vào bảng loans');
      }

      if (oldVersion < 3) {
        await db.execute('''
          CREATE TABLE $_tableBudgets (
            $_colBudgetId INTEGER PRIMARY KEY AUTOINCREMENT,
            $_colBudgetAmount REAL NOT NULL CHECK ($_colBudgetAmount >= 0),
            $_colBudgetCategoryId INTEGER,
            $_colBudgetStartDate TEXT NOT NULL,
            $_colBudgetEndDate TEXT NOT NULL,
            $_colBudgetCreatedAt TEXT NOT NULL,
            
            FOREIGN KEY ($_colBudgetCategoryId) REFERENCES $_tableCategories ($_colCategoryId) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE INDEX idx_budgets_category_id 
          ON $_tableBudgets ($_colBudgetCategoryId)
        ''');

        log('Đã tạo bảng budgets');
      }

      if (oldVersion < 4) {
        final hasColumn = await _checkColumnExists(db, _tableBudgets, _colBudgetCategoryId);

        if (hasColumn) {
          await db.execute('DROP TABLE IF EXISTS ${_tableBudgets}_old');
          await db.execute('ALTER TABLE $_tableBudgets RENAME TO ${_tableBudgets}_old');

          await db.execute('''
            CREATE TABLE $_tableBudgets (
              $_colBudgetId INTEGER PRIMARY KEY AUTOINCREMENT,
              $_colBudgetAmount REAL NOT NULL CHECK ($_colBudgetAmount >= 0),
              $_colBudgetCategoryId INTEGER,
              $_colBudgetStartDate TEXT NOT NULL,
              $_colBudgetEndDate TEXT NOT NULL,
              $_colBudgetCreatedAt TEXT NOT NULL,
              
              FOREIGN KEY ($_colBudgetCategoryId) REFERENCES $_tableCategories ($_colCategoryId) ON DELETE CASCADE
            )
          ''');

          await db.execute('''
            INSERT INTO $_tableBudgets 
            SELECT * FROM ${_tableBudgets}_old
          ''');

          await db.execute('DROP TABLE ${_tableBudgets}_old');

          await db.execute('''
            CREATE INDEX idx_budgets_category_id 
            ON $_tableBudgets ($_colBudgetCategoryId)
          ''');

          log('Đã migrate bảng budgets với category_id nullable');
        }
      }

      log('Nâng cấp database hoàn tất');
    } catch (e) {
      log('Lỗi nâng cấp database: $e');
      rethrow;
    }
  }

  /// Kiểm tra xem column có tồn tại trong table không
  Future<bool> _checkColumnExists(Database db, String tableName, String columnName) async {
    try {
      final result = await db.rawQuery('PRAGMA table_info($tableName)');
      return result.any((column) => column['name'] == columnName);
    } catch (e) {
      log('Lỗi kiểm tra column: $e');
      return false;
    }
  }

  // ==================== GENERIC DATABASE OPERATIONS ====================

  /// Generic insert
  Future<int> insert(String table, Map<String, dynamic> values) async {
    try {
      final db = await database;
      return await db.insert(table, values);
    } catch (e) {
      log('Lỗi insert vào $table: $e');
      rethrow;
    }
  }

  /// Generic update
  Future<int> update(String table, Map<String, dynamic> values, {String? where, List<dynamic>? whereArgs}) async {
    try {
      final db = await database;
      return await db.update(table, values, where: where, whereArgs: whereArgs);
    } catch (e) {
      log('Lỗi update $table: $e');
      rethrow;
    }
  }

  /// Generic delete
  Future<int> delete(String table, {String? where, List<dynamic>? whereArgs}) async {
    try {
      final db = await database;
      return await db.delete(table, where: where, whereArgs: whereArgs);
    } catch (e) {
      log('Lỗi delete từ $table: $e');
      rethrow;
    }
  }

  /// Generic query
  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<dynamic>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final db = await database;
      return await db.query(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      log('Lỗi query từ $table: $e');
      rethrow;
    }
  }

  /// Generic raw query
  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? arguments]) async {
    try {
      final db = await database;
      return await db.rawQuery(sql, arguments);
    } catch (e) {
      log('Lỗi raw query: $e');
      rethrow;
    }
  }

  /// Generic raw insert
  Future<int> rawInsert(String sql, [List<dynamic>? arguments]) async {
    try {
      final db = await database;
      return await db.rawInsert(sql, arguments);
    } catch (e) {
      log('Lỗi raw insert: $e');
      rethrow;
    }
  }

  /// Generic raw update
  Future<int> rawUpdate(String sql, [List<dynamic>? arguments]) async {
    try {
      final db = await database;
      return await db.rawUpdate(sql, arguments);
    } catch (e) {
      log('Lỗi raw update: $e');
      rethrow;
    }
  }

  /// Generic raw delete
  Future<int> rawDelete(String sql, [List<dynamic>? arguments]) async {
    try {
      final db = await database;
      return await db.rawDelete(sql, arguments);
    } catch (e) {
      log('Lỗi raw delete: $e');
      rethrow;
    }
  }

  /// Execute transaction
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    try {
      final db = await database;
      return await db.transaction(action);
    } catch (e) {
      log('Lỗi transaction: $e');
      rethrow;
    }
  }

  // ==================== UTILITY METHODS ====================

  /// Xóa toàn bộ dữ liệu (reset database)
  Future<void> clearAllData() async {
    try {
      final db = await database;

      await db.transaction((txn) async {
        await txn.delete(_tableNotifications);
        await txn.delete(_tableTransactions);
        await txn.delete(_tableLoans);
        await txn.delete(_tableCategories);
        await txn.delete(_tableUsers);
        await txn.delete(_tableBudgets);
      });

      log('Xóa toàn bộ dữ liệu thành công');
    } catch (e) {
      log('Lỗi xóa toàn bộ dữ liệu: $e');
      rethrow;
    }
  }

  /// Đóng kết nối database
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
      log('Đã đóng kết nối database');
    }
  }

  /// Xóa toàn bộ database và tạo lại từ đầu
  Future<void> resetDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, _databaseName);

      if (_database != null) {
        await _database!.close();
        _database = null;
      }

      await deleteDatabase(path);
      log('Database đã được xóa và sẽ tạo lại từ đầu');

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      log('SharedPreferences đã được xóa');
    } catch (e) {
      log('Lỗi khi reset database: $e');
      rethrow;
    }
  }

  /// Lấy user ID hiện tại từ SharedPreferences
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
}

