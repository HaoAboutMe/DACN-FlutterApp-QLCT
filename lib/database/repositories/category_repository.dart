import 'dart:developer';
import '../database_helper.dart';
import '../../models/category.dart';

class CategoryRepository {
  static final CategoryRepository _instance = CategoryRepository._internal();
  factory CategoryRepository() => _instance;
  CategoryRepository._internal();

  final DatabaseHelper _db = DatabaseHelper();

  Future<int> insertCategory(Category category) async {
    try {
      final db = await _db.database;
      final normalizedName = category.name.trim();

      final exists = await existsCategoryByNameIcon(
        normalizedName,
        category.type,
        category.icon,
      );

      if (exists) {
        throw Exception('DUPLICATE_CATEGORY');
      }

      final normalizedCategory = category.copyWith(name: normalizedName);
      final id = await db.insert('categories', normalizedCategory.toMap());
      log('Thêm category thành công với ID: $id');
      return id;
    } catch (e) {
      log('Lỗi thêm category: $e');
      rethrow;
    }
  }

  Future<bool> existsCategoryByNameIcon(String name, String type, String icon) async {
    try {
      final db = await _db.database;
      final result = await db.query(
        'categories',
        where: 'LOWER(TRIM(name)) = ? AND type = ? AND icon = ?',
        whereArgs: [name.toLowerCase().trim(), type, icon],
        limit: 1,
      );
      return result.isNotEmpty;
    } catch (e) {
      log('Lỗi kiểm tra category tồn tại: $e');
      return false;
    }
  }

  Future<List<Category>> searchCategories({
    required String type,
    String? keyword,
    List<String>? iconList,
  }) async {
    try {
      final db = await _db.database;

      String whereClause = 'type = ?';
      List<dynamic> whereArgs = [type];

      if (keyword != null && keyword.trim().isNotEmpty) {
        whereClause += ' AND LOWER(name) LIKE ?';
        whereArgs.add('%${keyword.toLowerCase().trim()}%');
      }

      if (iconList != null && iconList.isNotEmpty) {
        final iconPlaceholders = iconList.map((e) => '?').join(',');
        whereClause += ' AND icon IN ($iconPlaceholders)';
        whereArgs.addAll(iconList);
      }

      final maps = await db.query(
        'categories',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'name ASC',
      );

      return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi tìm kiếm categories: $e');
      return [];
    }
  }

  Future<int> updateCategory(Category category) async {
    try {
      final db = await _db.database;
      final count = await db.update(
        'categories',
        category.toMap(),
        where: 'id = ?',
        whereArgs: [category.id],
      );
      log('Cập nhật category thành công');
      return count;
    } catch (e) {
      log('Lỗi cập nhật category: $e');
      rethrow;
    }
  }

  Future<bool> _isCategoryInUse(int categoryId) async {
    try {
      final db = await _db.database;

      final transactionMaps = await db.query(
        'transactions',
        where: 'categoryId = ?',
        whereArgs: [categoryId],
        limit: 1,
      );

      if (transactionMaps.isNotEmpty) {
        log('Category ID $categoryId đang được sử dụng trong transactions');
        return true;
      }

      final budgetMaps = await db.query(
        'budgets',
        where: 'category_id = ?',
        whereArgs: [categoryId],
        limit: 1,
      );

      if (budgetMaps.isNotEmpty) {
        log('Category ID $categoryId đang được sử dụng trong budgets');
        return true;
      }

      return false;
    } catch (e) {
      log('Lỗi kiểm tra category in use: $e');
      rethrow;
    }
  }

  Future<int> deleteCategory(int id) async {
    try {
      final isInUse = await _isCategoryInUse(id);

      if (isInUse) {
        throw Exception('CATEGORY_IN_USE');
      }

      final db = await _db.database;
      final count = await db.delete(
        'categories',
        where: 'id = ?',
        whereArgs: [id],
      );
      log('Xóa category thành công');
      return count;
    } catch (e) {
      log('Lỗi xóa category: $e');
      rethrow;
    }
  }

  Future<List<Category>> getAllCategories() async {
    try {
      final db = await _db.database;
      final maps = await db.query('categories', orderBy: 'name ASC');
      return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy danh sách categories: $e');
      rethrow;
    }
  }

  Future<List<Category>> getCategoriesByType(String type) async {
    try {
      final db = await _db.database;
      final maps = await db.query(
        'categories',
        where: 'type = ?',
        whereArgs: [type],
        orderBy: 'name ASC',
      );
      return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy categories theo type: $e');
      rethrow;
    }
  }

  Future<Category?> getCategoryById(int id) async {
    try {
      final db = await _db.database;
      final maps = await db.query(
        'categories',
        where: 'id = ?',
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

  Future<bool> insertDefaultCategoriesIfNeeded() async {
    try {
      final existingCategories = await getAllCategories();

      if (existingCategories.isEmpty) {
        log('Database trống - bắt đầu khởi tạo danh mục mặc định');

        final defaultCategories = _getDefaultCategories();

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

  List<Category> _getDefaultCategories() {
    final now = DateTime.now();

    return [
      Category(name: 'Ăn uống', icon: 'restaurant', type: 'expense', createdAt: now),
      Category(name: 'Mua sắm', icon: 'shopping_bag', type: 'expense', createdAt: now),
      Category(name: 'Đi lại', icon: 'directions_car', type: 'expense', createdAt: now),
      Category(name: 'Giải trí', icon: 'movie', type: 'expense', createdAt: now),
      Category(name: 'Y tế', icon: 'medical_services', type: 'expense', createdAt: now),
      Category(name: 'Khác', icon: 'more_horiz', type: 'expense', createdAt: now),
      Category(name: 'Lương', icon: 'attach_money', type: 'income', createdAt: now),
      Category(name: 'Thưởng', icon: 'card_giftcard', type: 'income', createdAt: now),
      Category(name: 'Đầu tư', icon: 'trending_up', type: 'income', createdAt: now),
    ];
  }

  Future<List<Category>> getCategoriesWithBudget() async {
    try {
      final db = await _db.database;
      final maps = await db.query(
        'categories',
        where: 'budget > 0 OR id IN (SELECT DISTINCT category_id FROM budgets WHERE start_date <= ? AND end_date >= ?)',
        whereArgs: [DateTime.now().toIso8601String(), DateTime.now().toIso8601String()],
        orderBy: 'name ASC',
      );
      return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy categories có ngân sách: $e');
      rethrow;
    }
  }
}

