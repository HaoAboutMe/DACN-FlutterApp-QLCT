import 'dart:async';
import 'dart:developer';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category.dart';
import '../models/transaction.dart' as transaction_model;
import '../models/loan.dart';
import '../models/notification_data.dart';
import '../models/user.dart';
import '../models/budget.dart';

/// Lớp DatabaseHelper quản lý cơ sở dữ liệu SQLite cho ứng dụng quản lý chi tiêu
/// Sử dụng singleton pattern để đảm bảo chỉ có một instance duy nhất
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  // Thông tin database
  static const String _databaseName = 'expense_tracker.db';
  static const int _databaseVersion = 4; // Tăng version để trigger migration cho budget với category_id nullable

  // Tên các bảng
  static const String _tableUsers = 'users';
  static const String _tableCategories = 'categories';
  static const String _tableTransactions = 'transactions';
  static const String _tableLoans = 'loans';
  static const String _tableNotifications = 'notifications';
  static const String _tableBudgets = 'budgets'; // Bảng ngân sách riêng biệt

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
  static const String _colCategoryBudget = 'budget'; // Hạn mức chi tiêu cho danh mục
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
  /// Cột đánh dấu khoản vay/nợ cũ hay mới
  /// 0 = khoản vay/nợ mới (tạo transaction và cập nhật số dư khi khởi tạo)
  /// 1 = khoản vay/nợ cũ (chỉ ghi nhận, không tạo transaction ban đầu)
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

  // Cột của bảng budgets (bảng ngân sách riêng biệt)
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
          // Bật foreign keys
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
          $_colCategoryBudget REAL DEFAULT 0, -- Hạn mức chi tiêu cho danh mục
          $_colCategoryCreatedAt TEXT NOT NULL,
          UNIQUE($_colCategoryName, $_colCategoryType)
        )
      ''');

      // Tạo bảng loans với cột isOldDebt
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

      // Tạo bảng transactions với ràng buộc
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
          
          -- Ràng buộc: hoặc categoryId hoặc loanId, không được cả hai
          CHECK (
            ($_colTransactionCategoryId IS NOT NULL AND $_colTransactionLoanId IS NULL) OR
            ($_colTransactionCategoryId IS NULL AND $_colTransactionLoanId IS NOT NULL)
          ),
          
          -- Foreign keys
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

      // Tạo các index để tối ưu hiệu suất
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
      // Index cho bảng transactions
      await db.execute('''
        CREATE INDEX idx_transactions_date_type_category 
        ON $_tableTransactions ($_colTransactionDate, $_colTransactionType, $_colTransactionCategoryId)
      ''');

      await db.execute('''
        CREATE INDEX idx_transactions_loan_id 
        ON $_tableTransactions ($_colTransactionLoanId)
      ''');

      // Index cho bảng loans
      await db.execute('''
        CREATE INDEX idx_loans_status_due_date_name 
        ON $_tableLoans ($_colLoanStatus, $_colLoanDueDate, $_colLoanPersonName)
      ''');

      // Index cho bảng notifications
      await db.execute('''
        CREATE INDEX idx_notifications_loan_id_sent_at 
        ON $_tableNotifications ($_colNotificationLoanId, $_colNotificationSentAt)
      ''');

      // Index cho bảng budgets
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
        // Thêm cột isOldDebt vào bảng loans
        await db.execute('''
          ALTER TABLE $_tableLoans 
          ADD COLUMN $_colLoanIsOldDebt INTEGER NOT NULL DEFAULT 0 CHECK ($_colLoanIsOldDebt IN (0, 1))
        ''');
        log('Đã thêm cột isOldDebt vào bảng loans');
      }

      if (oldVersion < 3) {
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
        log('Đã tạo bảng budgets');

        // Thêm cột budget vào bảng categories
        await db.execute('''
          ALTER TABLE $_tableCategories 
          ADD COLUMN $_colCategoryBudget REAL DEFAULT 0
        ''');
        log('Đã thêm cột budget vào bảng categories');
      }

      if (oldVersion < 4) {
        // Migration: Sửa bảng budgets để cho phép category_id NULL (hỗ trợ ngân sách tổng)
        // SQLite không hỗ trợ ALTER COLUMN, nên phải tạo bảng mới và copy data

        log('Bắt đầu migration bảng budgets từ version 3 lên 4...');

        // 1. Đổi tên bảng cũ
        await db.execute('ALTER TABLE $_tableBudgets RENAME TO budgets_old');

        // 2. Tạo bảng mới với schema đúng (category_id nullable)
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

        // 3. Copy data từ bảng cũ sang bảng mới
        await db.execute('''
          INSERT INTO $_tableBudgets 
            ($_colBudgetId, $_colBudgetAmount, $_colBudgetCategoryId, $_colBudgetStartDate, $_colBudgetEndDate, $_colBudgetCreatedAt)
          SELECT 
            $_colBudgetId, $_colBudgetAmount, $_colBudgetCategoryId, $_colBudgetStartDate, $_colBudgetEndDate, $_colBudgetCreatedAt
          FROM budgets_old
        ''');

        // 4. Xóa bảng cũ
        await db.execute('DROP TABLE budgets_old');

        // 5. Tạo lại index cho bảng budgets
        await db.execute('''
          CREATE INDEX idx_budgets_category_id 
          ON $_tableBudgets ($_colBudgetCategoryId)
        ''');

        log('Đã hoàn thành migration bảng budgets - category_id giờ có thể NULL');
      }

      log('Nâng cấp database thành công');
    } catch (e) {
      log('Lỗi nâng cấp database: $e');
      rethrow;
    }
  }

  // ==================== CRUD cho Users ====================

  /// Thêm người dùng mới
  Future<int> insertUser(User user) async {
    try {
      final db = await database;
      final id = await db.insert(_tableUsers, user.toMap());
      log('Thêm user thành công với ID: $id');
      return id;
    } catch (e) {
      log('Lỗi thêm user: $e');
      rethrow;
    }
  }

  /// Cập nhật thông tin người dùng
  Future<int> updateUser(User user) async {
    try {
      final db = await database;
      final count = await db.update(
        _tableUsers,
        user.toMap(),
        where: '$_colUserId = ?',
        whereArgs: [user.id],
      );
      log('Cập nhật user thành công');
      return count;
    } catch (e) {
      log('Lỗi cập nhật user: $e');
      rethrow;
    }
  }

  /// Xóa người dùng
  Future<int> deleteUser(int id) async {
    try {
      final db = await database;
      final count = await db.delete(
        _tableUsers,
        where: '$_colUserId = ?',
        whereArgs: [id],
      );
      log('Xóa user thành công');
      return count;
    } catch (e) {
      log('Lỗi xóa user: $e');
      rethrow;
    }
  }

  /// Lấy tất cả người dùng
  Future<List<User>> getAllUsers() async {
    try {
      final db = await database;
      final maps = await db.query(_tableUsers);
      return List.generate(maps.length, (i) => User.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy danh sách users: $e');
      rethrow;
    }
  }

  /// Lấy người dùng theo ID
  Future<User?> getUserById(int id) async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableUsers,
        where: '$_colUserId = ?',
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

  /// Lấy số dư hiện tại của user đang đăng nhập
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

  /// Lấy user hiện tại đang đăng nhập
  Future<User?> getCurrentUser() async {
    try {
      final currentUserId = await getCurrentUserId();
      return await getUserById(currentUserId);
    } catch (e) {
      log('Error getting current user: $e');
      return null;
    }
  }

  // ==================== CRUD cho Categories ====================

  /// Thêm danh mục mới
  Future<int> insertCategory(Category category) async {
    try {
      final db = await database;

      // Chuẩn hóa tên danh mục
      final normalizedName = category.name.trim();

      // Kiểm tra trùng lặp
      final exists = await existsCategoryByNameIcon(
          normalizedName,
          category.type,
          category.icon
      );

      if (exists) {
        throw Exception('DUPLICATE_CATEGORY');
      }

      // Tạo category mới với tên đã chuẩn hóa
      final normalizedCategory = category.copyWith(name: normalizedName);

      final id = await db.insert(_tableCategories, normalizedCategory.toMap());
      log('Thêm category thành công với ID: $id');
      return id;
    } catch (e) {
      log('Lỗi thêm category: $e');
      rethrow;
    }
  }

  /// Kiểm tra tồn tại category theo tên, loại và icon
  Future<bool> existsCategoryByNameIcon(String name, String type, String icon) async {
    try {
      final db = await database;
      final result = await db.query(
        _tableCategories,
        where: 'LOWER(TRIM($_colCategoryName)) = ? AND $_colCategoryType = ? AND $_colCategoryIcon = ?',
        whereArgs: [name.toLowerCase().trim(), type, icon],
        limit: 1,
      );
      return result.isNotEmpty;
    } catch (e) {
      log('Lỗi kiểm tra category tồn tại: $e');
      return false;
    }
  }

  /// Tìm kiếm categories theo từ khóa và nhóm
  Future<List<Category>> searchCategories({
    required String type,
    String? keyword,
    List<String>? iconList,
  }) async {
    try {
      final db = await database;

      String whereClause = '$_colCategoryType = ?';
      List<dynamic> whereArgs = [type];

      // Thêm điều kiện tìm kiếm theo tên
      if (keyword != null && keyword.trim().isNotEmpty) {
        whereClause += ' AND LOWER($_colCategoryName) LIKE ?';
        whereArgs.add('%${keyword.toLowerCase().trim()}%');
      }

      // Thêm điều kiện lọc theo danh sách icon
      if (iconList != null && iconList.isNotEmpty) {
        final iconPlaceholders = iconList.map((e) => '?').join(',');
        whereClause += ' AND $_colCategoryIcon IN ($iconPlaceholders)';
        whereArgs.addAll(iconList);
      }

      final List<Map<String, dynamic>> maps = await db.query(
        _tableCategories,
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: '$_colCategoryName ASC',
      );

      return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi tìm kiếm categories: $e');
      return [];
    }
  }

  /// Cập nhật danh mục
  Future<int> updateCategory(Category category) async {
    try {
      final db = await database;
      final count = await db.update(
        _tableCategories,
        category.toMap(),
        where: '$_colCategoryId = ?',
        whereArgs: [category.id],
      );
      log('Cập nhật category thành công');
      return count;
    } catch (e) {
      log('Lỗi cập nhật category: $e');
      rethrow;
    }
  }

  /// Kiểm tra xem danh mục có đang được sử dụng không
  /// Trả về true nếu danh mục đang được tham chiếu trong transactions hoặc budgets
  Future<bool> _isCategoryInUse(int categoryId) async {
    try {
      final db = await database;

      // Kiểm tra trong bảng transactions
      final transactionMaps = await db.query(
        _tableTransactions,
        where: '$_colTransactionCategoryId = ?',
        whereArgs: [categoryId],
        limit: 1,
      );

      if (transactionMaps.isNotEmpty) {
        log('Category ID $categoryId đang được sử dụng trong ${transactionMaps.length} giao dịch');
        return true;
      }

      // Kiểm tra trong bảng budgets
      final budgetMaps = await db.query(
        _tableBudgets,
        where: '$_colBudgetCategoryId = ?',
        whereArgs: [categoryId],
        limit: 1,
      );

      if (budgetMaps.isNotEmpty) {
        log('Category ID $categoryId đang được sử dụng trong ${budgetMaps.length} ngân sách');
        return true;
      }

      return false;
    } catch (e) {
      log('Lỗi kiểm tra category in use: $e');
      rethrow;
    }
  }

  /// Xóa danh mục
  /// Throws Exception nếu danh mục đang được sử dụng trong transactions hoặc budgets
  Future<int> deleteCategory(int id) async {
    try {
      // Kiểm tra xem category có đang được sử dụng không
      final isInUse = await _isCategoryInUse(id);

      if (isInUse) {
        throw Exception('CATEGORY_IN_USE');
      }

      final db = await database;
      final count = await db.delete(
        _tableCategories,
        where: '$_colCategoryId = ?',
        whereArgs: [id],
      );
      log('Xóa category thành công');
      return count;
    } catch (e) {
      log('Lỗi xóa category: $e');
      rethrow;
    }
  }

  /// Lấy tất cả danh mục
  Future<List<Category>> getAllCategories() async {
    try {
      final db = await database;
      final maps = await db.query(_tableCategories, orderBy: '$_colCategoryName ASC');
      return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy danh sách categories: $e');
      rethrow;
    }
  }

  /// Lấy danh mục theo loại (income/expense)
  Future<List<Category>> getCategoriesByType(String type) async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableCategories,
        where: '$_colCategoryType = ?',
        whereArgs: [type],
        orderBy: '$_colCategoryName ASC',
      );
      return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy categories theo type: $e');
      rethrow;
    }
  }

  /// Lấy danh mục theo ID
  Future<Category?> getCategoryById(int id) async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableCategories,
        where: '$_colCategoryId = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty) {
        return Category.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      log('Lỗi lấy category theo ID: $e');
      rethrow;
    }
  }

  /// Khởi tạo danh mục mặc định nếu database trống
  /// Phương thức này nên được gọi khi app khởi động để đảm bảo có danh mục sẵn sàng
  /// Trả về true nếu đã thêm danh mục mặc định, false nếu database đã có danh mục
  Future<bool> insertDefaultCategoriesIfNeeded() async {
    try {
      // Kiểm tra xem đã có danh mục nào chưa
      final existingCategories = await getAllCategories();

      if (existingCategories.isEmpty) {
        log('Database trống - bắt đầu khởi tạo danh mục mặc định');

        // Import DefaultCategories để lấy danh sách
        final defaultCategories = _getDefaultCategories();

        // Thêm từng danh mục vào database
        for (final category in defaultCategories) {
          await insertCategory(category);
        }

        log('Đã khởi tạo ${defaultCategories.length} danh mục mặc định');
        return true;
      }

      log('Database đã có ${existingCategories.length} danh mục - bỏ qua khởi tạo mặc định');
      return false;
    } catch (e) {
      log('Lỗi khởi tạo danh mục mặc định: $e');
      rethrow;
    }
  }

  /// Helper method để lấy danh sách danh mục mặc định
  /// Tách riêng để tránh circular dependency khi import
  List<Category> _getDefaultCategories() {
    final now = DateTime.now();

    return [
      // Các danh mục chi tiêu (expense)
      Category(
        name: 'Ăn uống',
        icon: 'restaurant',
        type: 'expense',
        createdAt: now,
      ),
      Category(
        name: 'Mua sắm',
        icon: 'shopping_bag',
        type: 'expense',
        createdAt: now,
      ),
      Category(
        name: 'Đi lại',
        icon: 'directions_car',
        type: 'expense',
        createdAt: now,
      ),
      Category(
        name: 'Giải trí',
        icon: 'movie',
        type: 'expense',
        createdAt: now,
      ),
      Category(
        name: 'Y tế',
        icon: 'medical_services',
        type: 'expense',
        createdAt: now,
      ),
      Category(
        name: 'Khác',
        icon: 'more_horiz',
        type: 'expense',
        createdAt: now,
      ),

      // Các danh mục thu nhập (income)
      Category(
        name: 'Lương',
        icon: 'attach_money',
        type: 'income',
        createdAt: now,
      ),
      Category(
        name: 'Thưởng',
        icon: 'card_giftcard',
        type: 'income',
        createdAt: now,
      ),
      Category(
        name: 'Đầu tư',
        icon: 'trending_up',
        type: 'income',
        createdAt: now,
      ),
    ];
  }

  // ==================== CRUD cho Transactions ====================

  /// Thêm giao dịch mới
  Future<int> insertTransaction(transaction_model.Transaction transaction) async {
    try {
      final db = await database;
      final id = await db.insert(_tableTransactions, transaction.toMap());
      log('Thêm transaction thành công với ID: $id');
      return id;
    } catch (e) {
      log('Lỗi thêm transaction: $e');
      rethrow;
    }
  }

  /// Cập nhật giao dịch
  Future<int> updateTransaction(transaction_model.Transaction transaction) async {
    try {
      final db = await database;
      final count = await db.update(
        _tableTransactions,
        transaction.toMap(),
        where: '$_colTransactionId = ?',
        whereArgs: [transaction.id],
      );
      log('Cập nhật transaction thành công');
      return count;
    } catch (e) {
      log('Lỗi cập nhật transaction: $e');
      rethrow;
    }
  }

  /// Xóa giao dịch
  Future<int> deleteTransaction(int id) async {
    try {
      final db = await database;
      final count = await db.delete(
        _tableTransactions,
        where: '$_colTransactionId = ?',
        whereArgs: [id],
      );
      log('Xóa transaction thành công');
      return count;
    } catch (e) {
      log('Lỗi xóa transaction: $e');
      rethrow;
    }
  }

  /// Lấy tất cả giao dịch
  Future<List<transaction_model.Transaction>> getAllTransactions() async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableTransactions,
        orderBy: '$_colTransactionDate DESC, $_colTransactionId DESC',
      );
      return List.generate(maps.length, (i) => transaction_model.Transaction.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy danh sách transactions: $e');
      rethrow;
    }
  }

  /// Lấy giao dịch gần đây với giới hạn số lượng
  Future<List<transaction_model.Transaction>> getRecentTransactions({int limit = 10}) async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableTransactions,
        orderBy: '$_colTransactionDate DESC, $_colTransactionId DESC',
        limit: limit,
      );
      return List.generate(maps.length, (i) => transaction_model.Transaction.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy danh sách giao dịch gần đây: $e');
      rethrow;
    }
  }

  /// Lấy giao dịch theo ID
  Future<transaction_model.Transaction?> getTransactionById(int id) async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableTransactions,
        where: '$_colTransactionId = ?',
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

  /// Lấy giao dịch theo khoảng thời gian
  Future<List<transaction_model.Transaction>> getTransactionsByDateRange(DateTime startDate, DateTime endDate) async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableTransactions,
        where: '$_colTransactionDate BETWEEN ? AND ?',
        whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
        orderBy: '$_colTransactionDate DESC, $_colTransactionId DESC',
      );
      return List.generate(maps.length, (i) => transaction_model.Transaction.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy transactions theo khoảng thời gian: $e');
      rethrow;
    }
  }

  /// Lấy giao dịch theo loại
  Future<List<transaction_model.Transaction>> getTransactionsByType(String type) async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableTransactions,
        where: '$_colTransactionType = ?',
        whereArgs: [type],
        orderBy: '$_colTransactionDate DESC, $_colTransactionId DESC',
      );
      return List.generate(maps.length, (i) => transaction_model.Transaction.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy transactions theo type: $e');
      rethrow;
    }
  }

  /// Lấy giao dịch theo loan ID
  Future<List<transaction_model.Transaction>> getTransactionsByLoanId(int loanId) async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableTransactions,
        where: '$_colTransactionLoanId = ?',
        whereArgs: [loanId],
        orderBy: '$_colTransactionDate DESC, $_colTransactionId DESC',
      );
      return List.generate(maps.length, (i) => transaction_model.Transaction.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy transactions theo loanId: $e');
      rethrow;
    }
  }

  // ==================== CRUD cho Loans ====================

  /// Thêm khoản vay mới
  Future<int> insertLoan(Loan loan) async {
    try {
      final db = await database;
      final id = await db.insert(_tableLoans, loan.toMap());
      log('Thêm loan thành công với ID: $id');
      return id;
    } catch (e) {
      log('Lỗi thêm loan: $e');
      rethrow;
    }
  }

  /// Cập nhật khoản vay
  Future<int> updateLoan(Loan loan) async {
    try {
      final db = await database;

      // Get old loan data to calculate balance difference
      final oldLoanMaps = await db.query(
        _tableLoans,
        where: '$_colLoanId = ?',
        whereArgs: [loan.id],
      );

      if (oldLoanMaps.isEmpty) {
        throw Exception('Loan không tồn tại');
      }

      final oldLoan = Loan.fromMap(oldLoanMaps.first);

      // Update loan
      final count = await db.update(
        _tableLoans,
        loan.toMap(),
        where: '$_colLoanId = ?',
        whereArgs: [loan.id],
      );

      // Get current user ID
      final currentUserId = await getCurrentUserId();

      // ========== XỬ LÝ THAY ĐỔI isOldDebt ==========
      // Nếu isOldDebt thay đổi, cần xử lý transaction liên kết
      if (oldLoan.isOldDebt != loan.isOldDebt) {
        log('isOldDebt đã thay đổi: ${oldLoan.isOldDebt} -> ${loan.isOldDebt}');

        if (oldLoan.isOldDebt == 0 && loan.isOldDebt == 1) {
          // Từ khoản vay MỚI (0) → CŨ (1): Xóa transaction liên kết VÀ hoàn trả số dư
          log('Chuyển từ khoản vay mới sang cũ: Xóa transaction liên kết và hoàn trả số dư');

          final transactionMaps = await db.query(
            _tableTransactions,
            where: '$_colTransactionLoanId = ?',
            whereArgs: [loan.id],
            orderBy: '$_colTransactionCreatedAt ASC',
            limit: 1, // Lấy transaction khởi tạo đầu tiên
          );

          if (transactionMaps.isNotEmpty) {
            final transactionId = transactionMaps.first[_colTransactionId] as int;
            final transactionType = transactionMaps.first[_colTransactionType] as String;
            final transactionAmount = transactionMaps.first[_colTransactionAmount] as double;

            // Xóa transaction
            await db.delete(
              _tableTransactions,
              where: '$_colTransactionId = ?',
              whereArgs: [transactionId],
            );

            log('Đã xóa transaction ID $transactionId (type: $transactionType)');

            // Hoàn trả số dư về như ban đầu (đảo ngược hiệu ứng của transaction)
            double balanceChange = 0;
            if (transactionType == 'loan_received') {
              // Transaction cũ đã CỘNG tiền → cần TRỪ lại để hoàn trả
              balanceChange = -transactionAmount;
              log('Hoàn trả số dư: Trừ $transactionAmount (đã nhận khi vay)');
            } else if (transactionType == 'loan_given') {
              // Transaction cũ đã TRỪ tiền → cần CỘNG lại để hoàn trả
              balanceChange = transactionAmount;
              log('Hoàn trả số dư: Cộng $transactionAmount (đã cho vay)');
            }

            if (balanceChange != 0) {
              await db.rawUpdate(
                'UPDATE $_tableUsers SET $_colUserBalance = $_colUserBalance + ? WHERE $_colUserId = ?',
                [balanceChange, currentUserId],
              );
              log('Đã hoàn trả số dư người dùng: ${balanceChange > 0 ? "+$balanceChange" : balanceChange}');
            }
          }
        } else if (oldLoan.isOldDebt == 1 && loan.isOldDebt == 0) {
          // Từ khoản vay CŨ (1) → MỚI (0): Tạo transaction mới
          log('Chuyển từ khoản vay cũ sang mới: Tạo transaction mới');

          // Xác định loại transaction dựa trên loan type
          String transactionType;
          if (loan.loanType == 'borrow') {
            transactionType = 'loan_received'; // Vay tiền = nhận tiền vay
          } else {
            transactionType = 'loan_given'; // Cho vay = cho tiền vay
          }

          // Tạo transaction mới
          final newTransaction = transaction_model.Transaction(
            amount: loan.amount,
            description: loan.description ?? 'Khoản ${loan.loanType == 'borrow' ? 'vay' : 'cho vay'}: ${loan.personName}',
            date: loan.loanDate,
            categoryId: null,
            loanId: loan.id,
            type: transactionType,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await db.insert(_tableTransactions, newTransaction.toMap());
          log('Đã tạo transaction mới với type: $transactionType');

          // Cập nhật số dư người dùng
          double balanceChange = 0;
          if (transactionType == 'loan_received') {
            balanceChange = loan.amount; // Cộng tiền vào số dư
          } else if (transactionType == 'loan_given') {
            balanceChange = -loan.amount; // Trừ tiền khỏi số dư
          }

          if (balanceChange != 0) {
            await db.rawUpdate(
              'UPDATE $_tableUsers SET $_colUserBalance = $_colUserBalance + ? WHERE $_colUserId = ?',
              [balanceChange, currentUserId],
            );
            log('Cập nhật số dư người dùng: ${balanceChange > 0 ? "+$balanceChange" : balanceChange}');
          }
        }
      }

      // ========== XỬ LÝ CÁC THAY ĐỔI KHÁC (amount, loanType, description, loanDate) ==========
      // Chỉ cập nhật transaction nếu loan hiện tại là khoản vay MỚI (isOldDebt = 0)
      // và có thay đổi về amount, loanType, description, hoặc loanDate
      if (loan.isOldDebt == 0 && (oldLoan.amount != loan.amount ||
          oldLoan.loanType != loan.loanType ||
          oldLoan.description != loan.description ||
          oldLoan.loanDate != loan.loanDate)) {
        // Find the initial transaction for this loan
        final transactionMaps = await db.query(
          _tableTransactions,
          where: '$_colTransactionLoanId = ?',
          whereArgs: [loan.id],
          orderBy: '$_colTransactionCreatedAt ASC',
          limit: 1, // Get the first (initial) transaction
        );

        if (transactionMaps.isNotEmpty) {
          final transactionId = transactionMaps.first[_colTransactionId] as int;
          final oldTransactionAmount = transactionMaps.first[_colTransactionAmount] as double;
          final oldTransactionType = transactionMaps.first[_colTransactionType] as String;

          // Determine new transaction type based on loan type
          String newTransactionType;
          if (loan.loanType == 'borrow') {
            newTransactionType = 'loan_received'; // Vay tiền = nhận tiền vay
          } else {
            newTransactionType = 'loan_given'; // Cho vay = cho tiền vay
          }

          // Calculate balance changes only if amount or type changed
          double balanceChange = 0;
          bool shouldUpdateBalance = (oldLoan.amount != loan.amount || oldLoan.loanType != loan.loanType);

          if (shouldUpdateBalance) {
            // Reverse old transaction effect
            if (oldTransactionType == 'loan_received' || oldTransactionType == 'income') {
              balanceChange -= oldTransactionAmount; // Remove old income effect
            } else if (oldTransactionType == 'loan_given' || oldTransactionType == 'expense') {
              balanceChange += oldTransactionAmount; // Remove old expense effect
            }

            // Apply new transaction effect
            if (newTransactionType == 'loan_received') {
              balanceChange += loan.amount; // Add new income
            } else if (newTransactionType == 'loan_given') {
              balanceChange -= loan.amount; // Add new expense
            }
          }

          // Update the transaction
          await db.update(
            _tableTransactions,
            {
              _colTransactionAmount: loan.amount,
              _colTransactionType: newTransactionType,
              _colTransactionDate: loan.loanDate.toIso8601String(),
              _colTransactionDescription: loan.description ?? 'Khoản ${loan.loanType == 'borrow' ? 'vay' : 'cho vay'}: ${loan.personName}',
              _colTransactionUpdatedAt: DateTime.now().toIso8601String(),
            },
            where: '$_colTransactionId = ?',
            whereArgs: [transactionId],
          );

          // Update user balance only if amount or type changed
          if (shouldUpdateBalance && balanceChange != 0) {
            await db.rawUpdate(
              'UPDATE $_tableUsers SET $_colUserBalance = $_colUserBalance + ? WHERE $_colUserId = ?',
              [balanceChange, currentUserId],
            );
            log('Cập nhật số dư người dùng: ${balanceChange > 0 ? "+$balanceChange" : balanceChange}');
          }

          log('Cập nhật transaction liên quan với loan thành công');
        }
      }

      log('Cập nhật loan thành công');
      return count;
    } catch (e) {
      log('Lỗi cập nhật loan: $e');
      rethrow;
    }
  }

  /// Kiểm tra xem khoản vay có đang được sử dụng không
  /// Trả về true nếu khoản vay đang có giao dịch thanh toán (ngoài giao dịch khởi tạo)
  Future<bool> _isLoanInUse(int loanId) async {
    try {
      final db = await database;

      // Kiểm tra trong bảng transactions
      // Đếm số giao dịch liên quan đến loan này
      final transactionMaps = await db.query(
        _tableTransactions,
        where: '$_colTransactionLoanId = ?',
        whereArgs: [loanId],
      );

      // Nếu có nhiều hơn 1 giao dịch, nghĩa là đã có giao dịch thanh toán
      // (1 giao dịch đầu tiên là giao dịch khởi tạo khoản vay)
      if (transactionMaps.length > 1) {
        log('Loan ID $loanId đang có ${transactionMaps.length - 1} giao dịch thanh toán');
        return true;
      }

      return false;
    } catch (e) {
      log('Lỗi kiểm tra loan in use: $e');
      rethrow;
    }
  }

  /// Kiểm tra xem khoản vay có giao dịch liên quan không
  /// Trả về true nếu có ít nhất 1 transaction liên quan đến loan này (kể cả Transaction khởi tạo)
  /// Hàm này dùng để bảo vệ dữ liệu Transaction khỏi bị xóa khi xóa Loan
  Future<bool> _hasTransactionsForLoan(int loanId) async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $_tableTransactions WHERE $_colTransactionLoanId = ?',
        [loanId],
      );
      final count = Sqflite.firstIntValue(result) ?? 0;
      log('Loan ID $loanId có $count giao dịch liên quan');
      return count > 0;
    } catch (e) {
      log('Lỗi kiểm tra transactions cho loan: $e');
      rethrow;
    }
  }

  /// Xóa khoản vay
  /// ⚠️ QUAN TRỌNG: Chỉ cho phép xóa nếu KHÔNG có Transaction liên quan
  /// ⚠️ KHÔNG xóa Transaction tự động - bảo vệ dữ liệu lịch sử
  ///
  /// Throws Exception nếu:
  /// - Loan đã có Transaction liên quan (kể cả Transaction khởi tạo) → Exception('LOAN_HAS_TRANSACTIONS')
  /// - Loan đã thanh toán (status = 'paid') → Exception('LOAN_ALREADY_PAID')
  ///
  /// Chỉ cho phép xóa Loan khi:
  /// - Không có Transaction nào liên quan
  /// - Status = 'active' hoặc 'overdue' (chưa thanh toán)
  Future<int> deleteLoan(int id) async {
    try {
      final db = await database;

      // 1. Lấy thông tin khoản vay trước khi xóa
      final loanMaps = await db.query(
        _tableLoans,
        where: '$_colLoanId = ?',
        whereArgs: [id],
      );

      if (loanMaps.isEmpty) {
        log('Loan không tồn tại với ID: $id');
        return 0;
      }

      final loan = Loan.fromMap(loanMaps.first);
      log('Đang kiểm tra điều kiện xóa loan: ${loan.personName}, type: ${loan.loanType}, status: ${loan.status}');

      // 2. KIỂM TRA: Không cho phép xóa nếu loan đã thanh toán
      if (loan.status == 'paid' || loan.status == 'completed') {
        log('❌ Không thể xóa loan đã thanh toán: ${loan.personName}');
        throw Exception('LOAN_ALREADY_PAID');
      }

      // 3. KIỂM TRA: Không cho phép xóa nếu có Transaction liên quan (kể cả Transaction khởi tạo)
      final hasTransactions = await _hasTransactionsForLoan(id);
      if (hasTransactions) {
        log('❌ Không thể xóa loan vì đã có giao dịch liên quan: ${loan.personName}');
        throw Exception('LOAN_HAS_TRANSACTIONS');
      }

      // 4. ✅ Cho phép xóa - Cập nhật số dư nếu là khoản vay mới
      if (loan.isOldDebt == 0) {
        log('Cập nhật số dư trước khi xóa loan mới...');
        await _updateUserBalanceAfterLoanDeletion(loan);
      }

      // 5. ✅ Xóa loan (KHÔNG xóa Transaction - đã kiểm tra không có Transaction)
      final count = await db.delete(
        _tableLoans,
        where: '$_colLoanId = ?',
        whereArgs: [id],
      );

      log('✅ Xóa loan thành công: ${loan.personName}, đã xóa $count bản ghi');
      return count;
    } catch (e) {
      log('❌ Lỗi xóa loan: $e');
      rethrow;
    }
  }

  /// Cập nhật số dư user sau khi xóa khoản vay mới
  Future<void> _updateUserBalanceAfterLoanDeletion(Loan loan) async {
    try {
      // Lấy thông tin user hiện tại
      final currentUserId = await getCurrentUserId();
      final currentUser = await getUserById(currentUserId);

      if (currentUser == null) {
        log('Không tìm thấy user hiện tại');
        return;
      }

      double balanceChange = 0;

      // Tính toán thay đổi số dư dựa trên loại khoản vay
      if (loan.loanType == 'lend') {
        // Xóa khoản cho vay mới -> cộng lại tiền vào số dư (vì khi tạo đã bị trừ)
        balanceChange = loan.amount;
        log('Xóa khoản cho vay mới ${loan.amount} -> cộng lại vào số dư');
      } else if (loan.loanType == 'borrow') {
        // Xóa khoản đi vay mới -> trừ tiền khỏi số dư (vì khi tạo đã được cộng)
        balanceChange = -loan.amount;
        log('Xóa khoản đi vay mới ${loan.amount} -> trừ khỏi số dư');
      }

      // Cập nhật số dư mới
      final newBalance = currentUser.balance + balanceChange;
      final updatedUser = currentUser.copyWith(balance: newBalance);

      await updateUser(updatedUser);

      log('Đã cập nhật số dư từ ${currentUser.balance} thành $newBalance (thay đổi: $balanceChange)');
    } catch (e) {
      log('Lỗi cập nhật số dư sau khi xóa loan: $e');
      rethrow;
    }
  }

  /// Lấy tất cả khoản vay
  Future<List<Loan>> getAllLoans() async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableLoans,
        orderBy: '$_colLoanDate DESC, $_colLoanId DESC',
      );
      return List.generate(maps.length, (i) => Loan.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy danh sách loans: $e');
      rethrow;
    }
  }

  /// Lấy khoản vay theo ID
  Future<Loan?> getLoanById(int id) async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableLoans,
        where: '$_colLoanId = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty) {
        return Loan.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      log('Lỗi lấy loan theo ID: $e');
      rethrow;
    }
  }

  /// Lấy khoản vay theo trạng thái
  Future<List<Loan>> getLoansByStatus(String status) async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableLoans,
        where: '$_colLoanStatus = ?',
        whereArgs: [status],
        orderBy: '$_colLoanDueDate ASC, $_colLoanPersonName ASC',
      );
      return List.generate(maps.length, (i) => Loan.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy loans theo status: $e');
      rethrow;
    }
  }

  /// Lấy ID của loan vừa được insert
  Future<int?> getLastInsertedLoanId() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT last_insert_rowid() as id');
      if (result.isNotEmpty) {
        return result.first['id'] as int?;
      }
      return null;
    } catch (e) {
      log('Lỗi lấy last inserted loan ID: $e');
      rethrow;
    }
  }

  /// Lấy khoản vay theo loại (lend/borrow)
  Future<List<Loan>> getLoansByType(String loanType) async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableLoans,
        where: '$_colLoanType = ?',
        whereArgs: [loanType],
        orderBy: '$_colLoanDate DESC, $_colLoanId DESC',
      );
      return List.generate(maps.length, (i) => Loan.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy loans theo type: $e');
      rethrow;
    }
  }

  /// Lấy khoản vay sắp đến hạn
  Future<List<Loan>> getUpcomingLoans(int days) async {
    try {
      final db = await database;
      final upcomingDate = DateTime.now().add(Duration(days: days));

      final maps = await db.query(
        _tableLoans,
        where: '$_colLoanStatus = ? AND $_colLoanDueDate IS NOT NULL AND $_colLoanDueDate <= ?',
        whereArgs: ['active', upcomingDate.toIso8601String()],
        orderBy: '$_colLoanDueDate ASC',
      );
      return List.generate(maps.length, (i) => Loan.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy loans sắp đến hạn: $e');
      rethrow;
    }
  }

  /// Lấy danh sách nợ cũ (isOldDebt = 1)
  /// Đây là những khoản vay/nợ đã tồn tại từ trước, chỉ ghi nhận không tạo transaction ban đầu
  Future<List<Loan>> getOldDebts() async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableLoans,
        where: '$_colLoanIsOldDebt = ?',
        whereArgs: [1],
        orderBy: '$_colLoanDate DESC, $_colLoanId DESC',
      );
      return List.generate(maps.length, (i) => Loan.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy danh sách nợ cũ: $e');
      rethrow;
    }
  }

  /// Lấy danh sách khoản vay mới (isOldDebt = 0)
  /// Đây là những khoản vay/nợ mới tạo, sẽ tạo transaction và cập nhật số dư
  Future<List<Loan>> getNewLoans() async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableLoans,
        where: '$_colLoanIsOldDebt = ?',
        whereArgs: [0],
        orderBy: '$_colLoanDate DESC, $_colLoanId DESC',
      );
      return List.generate(maps.length, (i) => Loan.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy danh sách khoản vay mới: $e');
      rethrow;
    }
  }

  // ==================== CRUD cho Notifications ====================

  /// Thêm thông báo mới
  Future<int> insertNotification(NotificationData notification) async {
    try {
      final db = await database;
      final id = await db.insert(_tableNotifications, notification.toMap());
      log('Thêm notification thành công với ID: $id');
      return id;
    } catch (e) {
      log('Lỗi thêm notification: $e');
      rethrow;
    }
  }

  /// Cập nhật thông báo
  Future<int> updateNotification(NotificationData notification) async {
    try {
      final db = await database;
      final count = await db.update(
        _tableNotifications,
        notification.toMap(),
        where: '$_colNotificationId = ?',
        whereArgs: [notification.id],
      );
      log('Cập nhật notification thành công');
      return count;
    } catch (e) {
      log('Lỗi cập nhật notification: $e');
      rethrow;
    }
  }

  /// Xóa thông báo
  Future<int> deleteNotification(int id) async {
    try {
      final db = await database;
      final count = await db.delete(
        _tableNotifications,
        where: '$_colNotificationId = ?',
        whereArgs: [id],
      );
      log('Xóa notification thành công');
      return count;
    } catch (e) {
      log('Lỗi xóa notification: $e');
      rethrow;
    }
  }

  /// Lấy tất cả thông báo
  Future<List<NotificationData>> getAllNotifications() async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableNotifications,
        orderBy: '$_colNotificationSentAt DESC, $_colNotificationId DESC',
      );
      return List.generate(maps.length, (i) => NotificationData.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy danh sách notifications: $e');
      rethrow;
    }
  }

  /// Lấy thông báo chưa đọc
  Future<List<NotificationData>> getUnreadNotifications() async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableNotifications,
        where: '$_colNotificationIsRead = ?',
        whereArgs: [0],
        orderBy: '$_colNotificationSentAt DESC',
      );
      return List.generate(maps.length, (i) => NotificationData.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy notifications chưa đọc: $e');
      rethrow;
    }
  }

  /// Đánh dấu tất cả thông báo đã đọc
  Future<int> markAllNotificationsAsRead() async {
    try {
      final db = await database;
      final count = await db.update(
        _tableNotifications,
        {_colNotificationIsRead: 1},
        where: '$_colNotificationIsRead = ?',
        whereArgs: [0],
      );
      log('Đánh dấu tất cả notifications đã đọc');
      return count;
    } catch (e) {
      log('Lỗi đánh dấu notifications đã đọc: $e');
      rethrow;
    }
  }

  // ==================== Các hàm Business Logic sử dụng Transaction ====================

  /// Tạo khoản vay kèm giao dịch trong một transaction
  /// Đảm bảo dữ liệu nhất quán khi tạo loan và transaction liên quan
  ///
  /// Logic xử lý:
  /// - Nếu isOldDebt = 1 (nợ cũ): chỉ insert loan, KHÔNG tạo transaction, KHÔNG cập nhật số dư
  /// - Nếu isOldDebt = 0 (nợ mới): insert loan + transaction, cập nhật số dư:
  ///   + lend (cho vay) → tạo transaction 'loan_given', trừ số dư
  ///   + borrow (vay mới) → tạo transaction 'loan_received', cộng số dư
  Future<Map<String, int>> createLoanWithTransaction({
    required Loan loan,
    required transaction_model.Transaction transaction,
  }) async {
    final db = await database;
    // Get current user ID dynamically
    final currentUserId = await getCurrentUserId();

    try {
      late int loanId;
      int? transactionId;

      await db.transaction((txn) async {
        // 1. Tạo loan trước
        loanId = await txn.insert(_tableLoans, loan.toMap());
        log('Tạo loan với ID: $loanId');

        // 2. Kiểm tra isOldDebt để quyết định có tạo transaction hay không
        if (loan.isOldDebt == 0) {
          // Khoản vay/nợ mới: tạo transaction và cập nhật số dư
          log('Đây là khoản vay/nợ mới, tạo transaction và cập nhật số dư');

          // Tạo transaction với loanId vừa tạo
          final transactionWithLoanId = transaction.copyWith(loanId: loanId);
          transactionId = await txn.insert(_tableTransactions, transactionWithLoanId.toMap());
          log('Tạo transaction với ID: $transactionId');

          // Cập nhật số dư người dùng với currentUserId động
          await _updateUserBalanceInTransaction(
              txn,
              currentUserId,
              loan.amount,
              transaction.type
          );
        } else {
          // Khoản vay/nợ cũ: chỉ ghi nhận, không tạo transaction ban đầu
          log('Đây là khoản vay/nợ cũ, chỉ ghi nhận không tạo transaction ban đầu');
          transactionId = null;
        }
      });

      log('Tạo loan kèm transaction thành công cho user ID: $currentUserId');
      return {
        'loanId': loanId,
        'transactionId': transactionId ?? -1
      };
    } catch (e) {
      log('Lỗi tạo loan kèm transaction: $e');
      rethrow;
    }
  }

  /// Cập nhật số dư người dùng trong transaction (helper method)
  Future<void> _updateUserBalanceInTransaction(
      Transaction txn,
      int userId,
      double amount,
      String transactionType,
      ) async {
    // Debug log để theo dõi input parameters
    log('=== DEBUG _updateUserBalanceInTransaction ===');
    log('Input userId: $userId');
    log('Input amount: $amount');
    log('Input transactionType: $transactionType');

    // Lấy số dư hiện tại
    final userMaps = await txn.query(
      _tableUsers,
      where: '$_colUserId = ?',
      whereArgs: [userId],
    );

    if (userMaps.isEmpty) {
      throw Exception('Không tìm thấy người dùng với ID: $userId');
    }

    final currentUser = User.fromMap(userMaps.first);
    double newBalance = currentUser.balance;

    log('Current user balance before update: ${currentUser.balance}');

    // Tính toán số dư mới
    switch (transactionType) {
      case 'income':
      case 'debt_collected':
      case 'loan_received': // Nhận tiền vay
        newBalance += amount;
        log('Adding $amount to balance (type: $transactionType)');
        break;
      case 'expense':
      case 'loan_given': // Cho vay
      case 'debt_paid':
        newBalance -= amount;
        log('Subtracting $amount from balance (type: $transactionType)');
        break;
    }

    // Cập nhật số dư
    final updatedUser = currentUser.copyWith(
      balance: newBalance,
      updatedAt: DateTime.now(),
    );

    await txn.update(
      _tableUsers,
      updatedUser.toMap(),
      where: '$_colUserId = ?',
      whereArgs: [userId],
    );

    log('Cập nhật số dư user ID $userId: ${currentUser.balance} -> $newBalance');
    log('=== END DEBUG _updateUserBalanceInTransaction ===');
  }

  /// Đánh dấu khoản vay đã thanh toán và tạo giao dịch thanh toán
  /// Sử dụng transaction để đảm bảo tính nhất quán
  ///
  /// Logic xử lý:
  /// Bất kể loan mới hay cũ (isOldDebt = 0 hoặc 1), khi đánh dấu Paid thì:
  /// - Update loan status = 'paid', paidDate = now
  /// - Thêm transaction thanh toán:
  ///   + 'debt_paid' nếu borrow (trả nợ) → trừ số dư
  ///   + 'debt_collected' nếu lend (thu nợ) → cộng số dư
  /// - Cập nhật số dư tương ứng
  Future<bool> markLoanAsPaid({
    required int loanId,
    required transaction_model.Transaction paymentTransaction,
    int? userId, // Không còn hardcode = 1
  }) async {
    final db = await database;

    try {
      // Lấy userId hiện tại nếu không được truyền vào
      final currentUserId = userId ?? await getCurrentUserId();
      log('Using user ID: $currentUserId for marking loan as paid');

      await db.transaction((txn) async {
        // 1. Lấy thông tin loan hiện tại
        final loanMaps = await txn.query(
          _tableLoans,
          where: '$_colLoanId = ?',
          whereArgs: [loanId],
        );

        if (loanMaps.isEmpty) {
          throw Exception('Không tìm thấy khoản vay với ID: $loanId');
        }

        final currentLoan = Loan.fromMap(loanMaps.first);

        // 2. Cập nhật trạng thái loan thành 'paid'
        final updatedLoan = currentLoan.copyWith(
          status: 'paid',
          paidDate: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await txn.update(
          _tableLoans,
          updatedLoan.toMap(),
          where: '$_colLoanId = ?',
          whereArgs: [loanId],
        );

        log('Cập nhật loan ID $loanId thành trạng thái paid (isOldDebt: ${currentLoan.isOldDebt})');

        // 3. Tạo transaction thanh toán (bất kể loan cũ hay mới)
        final transactionWithLoanId = paymentTransaction.copyWith(loanId: loanId);
        await txn.insert(_tableTransactions, transactionWithLoanId.toMap());

        log('Tạo transaction thanh toán cho loan ID $loanId với type: ${paymentTransaction.type}');

        // 4. Cập nhật số dư người dùng
        await _updateUserBalanceInTransaction(
          txn,
          currentUserId, // Sử dụng currentUserId thay vì hardcode
          paymentTransaction.amount,
          paymentTransaction.type,
        );
      });

      log('Đánh dấu loan đã thanh toán thành công');
      return true;
    } catch (e) {
      log('Lỗi đánh dấu loan đã thanh toán: $e');
      rethrow;
    }
  }

  /// Cập nhật số dư người dùng sau giao dịch
  /// Sử dụng transaction để đảm bảo tính nhất quán
  Future<bool> updateUserBalanceAfterTransaction({
    int? userId, // Không còn hardcode = 1
    required double amount,
    required String transactionType,
  }) async {
    final db = await database;

    try {
      // Lấy userId hiện tại nếu không được truyền vào
      final currentUserId = userId ?? await getCurrentUserId();
      log('Using user ID: $currentUserId for updating balance after transaction');

      await db.transaction((txn) async {
        await _updateUserBalanceInTransaction(txn, currentUserId, amount, transactionType);
      });

      return true;
    } catch (e) {
      log('Lỗi cập nhật số dư user: $e');
      rethrow;
    }
  }

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

  // ==================== Các hàm thống kê và báo cáo ====================

  /// Tính tổng thu nhập trong khoảng thời gian
  Future<double> getTotalIncomeInPeriod(DateTime startDate, DateTime endDate) async {
    try {
      final db = await database;
      final result = await db.rawQuery('''
        SELECT SUM($_colTransactionAmount) as total
        FROM $_tableTransactions
        WHERE $_colTransactionType IN ('income', 'debt_collected', 'loan_received')
        AND $_colTransactionDate BETWEEN ? AND ?
      ''', [startDate.toIso8601String(), endDate.toIso8601String()]);

      return (result.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      log('Lỗi tính tổng thu nhập: $e');
      rethrow;
    }
  }

  /// Tính tổng chi tiêu trong khoảng thời gian
  Future<double> getTotalExpenseInPeriod(DateTime startDate, DateTime endDate) async {
    try {
      final db = await database;
      final result = await db.rawQuery('''
        SELECT SUM($_colTransactionAmount) as total
        FROM $_tableTransactions
        WHERE $_colTransactionType IN ('expense', 'loan_given', 'debt_paid')
        AND $_colTransactionDate BETWEEN ? AND ?
      ''', [startDate.toIso8601String(), endDate.toIso8601String()]);

      return (result.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      log('Lỗi tính tổng chi tiêu: $e');
      rethrow;
    }
  }

  /// Lấy báo cáo chi tiêu theo danh mục trong khoảng thời gian
  Future<List<Map<String, dynamic>>> getExpenseReportByCategory(
      DateTime startDate, DateTime endDate) async {
    try {
      final db = await database;
      final result = await db.rawQuery('''
        SELECT
          c.$_colCategoryName as categoryName,
          c.$_colCategoryIcon as categoryIcon,
          SUM(t.$_colTransactionAmount) as totalAmount,
          COUNT(t.$_colTransactionId) as transactionCount
        FROM $_tableTransactions t
        INNER JOIN $_tableCategories c ON t.$_colTransactionCategoryId = c.$_colCategoryId
        WHERE t.$_colTransactionType = 'expense'
        AND t.$_colTransactionDate BETWEEN ? AND ?
        GROUP BY c.$_colCategoryId, c.$_colCategoryName, c.$_colCategoryIcon
        ORDER BY totalAmount DESC
      ''', [startDate.toIso8601String(), endDate.toIso8601String()]);

      return result;
    } catch (e) {
      log('Lỗi lấy báo cáo chi tiêu theo danh mục: $e');
      rethrow;
    }
  }

  // ==================== CRUD cho Budgets ====================

  /// Thêm ngân sách mới
  Future<int> insertBudget(Budget budget) async {
    try {
      final db = await database;
      final id = await db.insert(_tableBudgets, budget.toMap());
      log('Thêm budget thành công với ID: $id');
      return id;
    } catch (e) {
      log('Lỗi thêm budget: $e');
      rethrow;
    }
  }

  /// Cập nhật ngân sách
  Future<int> updateBudget(Budget budget) async {
    try {
      final db = await database;
      final count = await db.update(
        _tableBudgets,
        budget.toMap(),
        where: '$_colBudgetId = ?',
        whereArgs: [budget.id],
      );
      log('Cập nhật budget thành công');
      return count;
    } catch (e) {
      log('Lỗi cập nhật budget: $e');
      rethrow;
    }
  }

  /// Xóa ngân sách
  Future<int> deleteBudget(int id) async {
    try {
      final db = await database;
      final count = await db.delete(
        _tableBudgets,
        where: '$_colBudgetId = ?',
        whereArgs: [id],
      );
      log('Xóa budget thành công');
      return count;
    } catch (e) {
      log('Lỗi xóa budget: $e');
      rethrow;
    }
  }

  /// Lấy tất cả ngân sách
  Future<List<Budget>> getAllBudgets() async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableBudgets,
        orderBy: '$_colBudgetStartDate DESC, $_colBudgetId DESC',
      );
      return List.generate(maps.length, (i) => Budget.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy danh sách budgets: $e');
      rethrow;
    }
  }

  /// Lấy ngân sách theo ID
  Future<Budget?> getBudgetById(int id) async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableBudgets,
        where: '$_colBudgetId = ?',
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

  /// Lấy ngân sách theo danh mục
  Future<List<Budget>> getBudgetsByCategory(int categoryId) async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableBudgets,
        where: '$_colBudgetCategoryId = ?',
        whereArgs: [categoryId],
        orderBy: '$_colBudgetStartDate DESC',
      );
      return List.generate(maps.length, (i) => Budget.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy budgets theo category: $e');
      rethrow;
    }
  }

  /// Lấy ngân sách đang hoạt động (trong khoảng thời gian hiện tại)
  Future<List<Budget>> getActiveBudgets() async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();

      final maps = await db.query(
        _tableBudgets,
        where: '$_colBudgetStartDate <= ? AND $_colBudgetEndDate >= ?',
        whereArgs: [now, now],
        orderBy: '$_colBudgetAmount DESC',
      );
      return List.generate(maps.length, (i) => Budget.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy budgets đang hoạt động: $e');
      rethrow;
    }
  }

  /// Lấy ngân sách đang hoạt động theo danh mục
  Future<Budget?> getActiveBudgetByCategory(int categoryId) async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();

      final maps = await db.query(
        _tableBudgets,
        where: '$_colBudgetCategoryId = ? AND $_colBudgetStartDate <= ? AND $_colBudgetEndDate >= ?',
        whereArgs: [categoryId, now, now],
        orderBy: '$_colBudgetStartDate DESC',
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

  /// Lấy ngân sách tổng đang hoạt động (categoryId = null)
  Future<Budget?> getActiveOverallBudget() async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();

      final maps = await db.query(
        _tableBudgets,
        where: '$_colBudgetCategoryId IS NULL AND $_colBudgetStartDate <= ? AND $_colBudgetEndDate >= ?',
        whereArgs: [now, now],
        orderBy: '$_colBudgetStartDate DESC',
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

  /// Lấy tiến độ ngân sách tổng (overall budget progress)
  Future<Map<String, dynamic>?> getOverallBudgetProgress() async {
    try {
      final overallBudget = await getActiveOverallBudget();
      if (overallBudget == null) return null;

      final totalSpent = await getTotalExpenseInPeriod(
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
        'startDate': overallBudget.startDate.toIso8601String(),
        'endDate': overallBudget.endDate.toIso8601String(),
      };
    } catch (e) {
      log('Lỗi lấy tiến độ ngân sách tổng: $e');
      rethrow;
    }
  }

  // ==================== Các hàm theo dõi ngân sách ====================

  /// Tính tổng chi tiêu theo danh mục trong khoảng thời gian ngân sách
  Future<double> getCategoryExpenseInBudgetPeriod(int categoryId, DateTime startDate, DateTime endDate) async {
    try {
      final db = await database;
      final result = await db.rawQuery('''
        SELECT SUM($_colTransactionAmount) as total
        FROM $_tableTransactions
        WHERE $_colTransactionType = 'expense'
        AND $_colTransactionCategoryId = ?
        AND $_colTransactionDate BETWEEN ? AND ?
      ''', [categoryId, startDate.toIso8601String(), endDate.toIso8601String()]);

      return (result.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      log('Lỗi tính chi tiêu theo category trong budget period: $e');
      rethrow;
    }
  }

  /// Lấy báo cáo tiến độ ngân sách cho tất cả danh mục có ngân sách đang hoạt động
  Future<List<Map<String, dynamic>>> getBudgetProgress() async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();

      final result = await db.rawQuery('''
        SELECT 
          b.$_colBudgetId as budgetId,
          b.$_colBudgetAmount as budgetAmount,
          b.$_colBudgetStartDate as startDate,
          b.$_colBudgetEndDate as endDate,
          c.$_colCategoryId as categoryId,
          c.$_colCategoryName as categoryName,
          c.$_colCategoryIcon as categoryIcon,
          COALESCE(SUM(t.$_colTransactionAmount), 0) as totalSpent
        FROM $_tableBudgets b
        INNER JOIN $_tableCategories c ON b.$_colBudgetCategoryId = c.$_colCategoryId
        LEFT JOIN $_tableTransactions t ON t.$_colTransactionCategoryId = c.$_colCategoryId 
          AND t.$_colTransactionType = 'expense'
          AND t.$_colTransactionDate BETWEEN b.$_colBudgetStartDate AND b.$_colBudgetEndDate
        WHERE b.$_colBudgetStartDate <= ? AND b.$_colBudgetEndDate >= ?
        GROUP BY b.$_colBudgetId, b.$_colBudgetAmount, b.$_colBudgetStartDate, b.$_colBudgetEndDate, 
                 c.$_colCategoryId, c.$_colCategoryName, c.$_colCategoryIcon
        ORDER BY (COALESCE(SUM(t.$_colTransactionAmount), 0) / b.$_colBudgetAmount) DESC
      ''', [now, now]);

      return result.map((row) {
        final budgetAmount = (row['budgetAmount'] as num).toDouble();
        final totalSpent = (row['totalSpent'] as num).toDouble();
        final progressPercentage = budgetAmount > 0 ? (totalSpent / budgetAmount) * 100 : 0.0;

        return {
          ...row,
          'progressPercentage': progressPercentage,
          'remainingAmount': budgetAmount - totalSpent,
          'isOverBudget': totalSpent > budgetAmount,
        };
      }).toList();
    } catch (e) {
      log('Lỗi lấy báo cáo tiến độ ngân sách: $e');
      rethrow;
    }
  }

  /// Lấy báo cáo tiến độ ngân sách cho danh mục cụ thể
  Future<Map<String, dynamic>?> getBudgetProgressByCategory(int categoryId) async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();

      final result = await db.rawQuery('''
        SELECT 
          b.$_colBudgetId as budgetId,
          b.$_colBudgetAmount as budgetAmount,
          b.$_colBudgetStartDate as startDate,
          b.$_colBudgetEndDate as endDate,
          c.$_colCategoryId as categoryId,
          c.$_colCategoryName as categoryName,
          c.$_colCategoryIcon as categoryIcon,
          COALESCE(SUM(t.$_colTransactionAmount), 0) as totalSpent
        FROM $_tableBudgets b
        INNER JOIN $_tableCategories c ON b.$_colBudgetCategoryId = c.$_colCategoryId
        LEFT JOIN $_tableTransactions t ON t.$_colTransactionCategoryId = c.$_colCategoryId 
          AND t.$_colTransactionType = 'expense'
          AND t.$_colTransactionDate BETWEEN b.$_colBudgetStartDate AND b.$_colBudgetEndDate
        WHERE c.$_colCategoryId = ?
          AND b.$_colBudgetStartDate <= ? AND b.$_colBudgetEndDate >= ?
        GROUP BY b.$_colBudgetId, b.$_colBudgetAmount, b.$_colBudgetStartDate, b.$_colBudgetEndDate, 
                 c.$_colCategoryId, c.$_colCategoryName, c.$_colCategoryIcon
        ORDER BY b.$_colBudgetStartDate DESC
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

  /// Kiểm tra xem có danh mục nào vượt ngân sách không
  Future<List<Map<String, dynamic>>> getOverBudgetCategories() async {
    try {
      final progressList = await getBudgetProgress();
      return progressList.where((item) => item['isOverBudget'] == true).toList();
    } catch (e) {
      log('Lỗi lấy danh sách categories vượt ngân sách: $e');
      rethrow;
    }
  }

  /// Lấy tổng ngân sách đang hoạt động
  Future<double> getTotalActiveBudget() async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();

      final result = await db.rawQuery('''
        SELECT SUM($_colBudgetAmount) as total
        FROM $_tableBudgets
        WHERE $_colBudgetStartDate <= ? AND $_colBudgetEndDate >= ?
      ''', [now, now]);

      return (result.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      log('Lỗi tính tổng ngân sách đang hoạt động: $e');
      rethrow;
    }
  }

  /// Lấy tổng chi tiêu trong tháng hiện tại
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

  /// Lấy danh mục có ngân sách đang hoạt động (có budget > 0 trong categories hoặc có budget riêng)
  Future<List<Category>> getCategoriesWithBudget() async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableCategories,
        where: '$_colCategoryBudget > 0 OR $_colCategoryId IN (SELECT DISTINCT $_colBudgetCategoryId FROM $_tableBudgets WHERE $_colBudgetStartDate <= ? AND $_colBudgetEndDate >= ?)',
        whereArgs: [DateTime.now().toIso8601String(), DateTime.now().toIso8601String()],
        orderBy: '$_colCategoryName ASC',
      );
      return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy categories có ngân sách: $e');
      rethrow;
    }
  }

  /// Lấy user ID hiện tại từ SharedPreferences
  /// Trả về 1 nếu không tìm thấy (fallback cho compatibility)
  Future<int> getCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('currentUserId') ?? 1;
      log('Current user ID: $userId');
      return userId;
    } catch (e) {
      log('Error getting current user ID: $e');
      return 1; // Fallback
    }
  }

  /// Xóa toàn bộ database và tạo lại từ đầu
  Future<void> resetDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, _databaseName);

      // Đóng database hiện tại nếu đang mở
      if (_database != null) {
        await _database!.close();
        _database = null;
      }

      // Xóa file database
      await deleteDatabase(path);
      log('Database đã được xóa và sẽ tạo lại từ đầu');

      // Xóa SharedPreferences để reset app về trạng thái ban đầu
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      log('SharedPreferences đã được xóa');

    } catch (e) {
      log('Lỗi khi reset database: $e');
      rethrow;
    }
  }

  // ==================== Phương thức hỗ trợ Notification System ====================

  /// Lấy tất cả khoản vay đang active và có bật nhắc nhở
  Future<List<Loan>> getActiveLoansWithReminders() async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableLoans,
        where: '$_colLoanStatus IN (?, ?) AND $_colLoanReminderEnabled = ?',
        whereArgs: ['active', 'overdue', 1],
        orderBy: '$_colLoanDueDate ASC',
      );
      return List.generate(maps.length, (i) => Loan.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy active loans với reminders: $e');
      rethrow;
    }
  }

  /// Cập nhật thời gian gửi nhắc nhở cuối cùng cho loan
  Future<int> updateLoanLastReminderSent(int loanId, DateTime sentAt) async {
    try {
      final db = await database;
      final count = await db.update(
        _tableLoans,
        {
          _colLoanLastReminderSent: sentAt.toIso8601String(),
          _colLoanUpdatedAt: DateTime.now().toIso8601String(),
        },
        where: '$_colLoanId = ?',
        whereArgs: [loanId],
      );
      log('Cập nhật last reminder sent cho loan $loanId');
      return count;
    } catch (e) {
      log('Lỗi cập nhật last reminder sent: $e');
      rethrow;
    }
  }

  /// Cập nhật trạng thái của loan
  Future<int> updateLoanStatus(int loanId, String status) async {
    try {
      final db = await database;
      final count = await db.update(
        _tableLoans,
        {
          _colLoanStatus: status,
          _colLoanUpdatedAt: DateTime.now().toIso8601String(),
        },
        where: '$_colLoanId = ?',
        whereArgs: [loanId],
      );
      log('Cập nhật trạng thái loan $loanId thành $status');
      return count;
    } catch (e) {
      log('Lỗi cập nhật trạng thái loan: $e');
      rethrow;
    }
  }

  /// Lấy danh sách notification theo loanId
  Future<List<NotificationData>> getNotificationsByLoanId(int loanId) async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableNotifications,
        where: '$_colNotificationLoanId = ?',
        whereArgs: [loanId],
        orderBy: '$_colNotificationSentAt DESC',
      );
      return List.generate(maps.length, (i) => NotificationData.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy notifications theo loanId: $e');
      rethrow;
    }
  }

  /// Đếm số notification chưa đọc
  Future<int> getUnreadNotificationCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $_tableNotifications WHERE $_colNotificationIsRead = 0'
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      log('Lỗi đếm notifications chưa đọc: $e');
      rethrow;
    }
  }

  /// Lấy tất cả notifications (có phân trang nếu cần)
  Future<List<NotificationData>> getAllNotificationsPaginated({int limit = 50, int offset = 0}) async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableNotifications,
        orderBy: '$_colNotificationSentAt DESC',
        limit: limit,
        offset: offset,
      );
      return List.generate(maps.length, (i) => NotificationData.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy danh sách notifications: $e');
      rethrow;
    }
  }

  /// Xóa tất cả notifications
  Future<int> deleteAllNotifications() async {
    try {
      final db = await database;
      final count = await db.delete(_tableNotifications);
      log('Đã xóa tất cả $count notifications');
      return count;
    } catch (e) {
      log('Lỗi xóa tất cả notifications: $e');
      rethrow;
    }
  }

  /// Xóa notification theo ID
  Future<int> deleteNotificationById(int id) async {
    try {
      final db = await database;
      final count = await db.delete(
        _tableNotifications,
        where: '$_colNotificationId = ?',
        whereArgs: [id],
      );
      log('Đã xóa notification ID $id');
      return count;
    } catch (e) {
      log('Lỗi xóa notification: $e');
      rethrow;
    }
  }

  /// Đánh dấu notification là đã đọc
  Future<int> markNotificationAsRead(int id) async {
    try {
      final db = await database;
      final count = await db.update(
        _tableNotifications,
        {_colNotificationIsRead: 1},
        where: '$_colNotificationId = ?',
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