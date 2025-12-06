import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/repositories/category_repository.dart';
import '../models/category.dart';
import '../models/quick_action_shortcut.dart';

class QuickActionService {
  static const String _defaultKey = 'quick_action_shortcuts';
  static const int defaultMaxShortcuts = 3;
  static const String _widgetKey = 'widget_quick_action_shortcuts';
  static const int widgetMaxShortcuts = 5;

  final String storageKey;
  final int maxShortcuts;

  const QuickActionService({
    this.storageKey = _defaultKey,
    this.maxShortcuts = defaultMaxShortcuts,
  });

  const QuickActionService.widget()
      : storageKey = _widgetKey,
        maxShortcuts = widgetMaxShortcuts;

  bool get isWidgetService => storageKey == _widgetKey;

  // Get all shortcuts
  Future<List<QuickActionShortcut>> getShortcuts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(storageKey);

      if (jsonString == null || jsonString.isEmpty) {
        if (isWidgetService) {
          final defaults = await _buildDefaultWidgetShortcuts();
          if (defaults.isNotEmpty) {
            await saveShortcuts(defaults);
            return defaults;
          }
        }
        return [];
      }

      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList
          .map((json) => QuickActionShortcut.fromJson(json))
          .toList();
    } catch (e) {
      print('Error loading shortcuts: $e');
      return [];
    }
  }

  // Save shortcuts
  Future<bool> saveShortcuts(List<QuickActionShortcut> shortcuts) async {
    try {
      if (shortcuts.length > maxShortcuts) {
        throw Exception('Chỉ được phép tối đa $maxShortcuts phím tắt');
      }

      final prefs = await SharedPreferences.getInstance();
      final jsonList = shortcuts.map((s) => s.toJson()).toList();
      final jsonString = json.encode(jsonList);

      return await prefs.setString(storageKey, jsonString);
    } catch (e) {
      print('Error saving shortcuts: $e');
      return false;
    }
  }

  // Add a new shortcut
  Future<bool> addShortcut(QuickActionShortcut shortcut) async {
    try {
      final shortcuts = await getShortcuts();

      if (shortcuts.length >= maxShortcuts) {
        throw Exception('Đã đạt giới hạn $maxShortcuts phím tắt');
      }

      // Assign ID based on position
      final newShortcut = shortcut.copyWith(id: shortcuts.length);
      shortcuts.add(newShortcut);

      return await saveShortcuts(shortcuts);
    } catch (e) {
      print('Error adding shortcut: $e');
      return false;
    }
  }

  // Update a shortcut
  Future<bool> updateShortcut(int id, QuickActionShortcut shortcut) async {
    try {
      final shortcuts = await getShortcuts();
      final index = shortcuts.indexWhere((s) => s.id == id);

      if (index == -1) {
        return false;
      }

      shortcuts[index] = shortcut.copyWith(id: id);
      return await saveShortcuts(shortcuts);
    } catch (e) {
      print('Error updating shortcut: $e');
      return false;
    }
  }

  // Delete a shortcut
  Future<bool> deleteShortcut(int id) async {
    try {
      final shortcuts = await getShortcuts();
      shortcuts.removeWhere((s) => s.id == id);

      // Reassign IDs
      for (int i = 0; i < shortcuts.length; i++) {
        shortcuts[i] = shortcuts[i].copyWith(id: i);
      }

      return await saveShortcuts(shortcuts);
    } catch (e) {
      print('Error deleting shortcut: $e');
      return false;
    }
  }

  /// Persist the current ordering of shortcuts after drag-and-drop.
  Future<bool> reorderShortcuts(List<QuickActionShortcut> orderedShortcuts) async {
    final normalized = <QuickActionShortcut>[];
    for (int i = 0; i < orderedShortcuts.length; i++) {
      normalized.add(orderedShortcuts[i].copyWith(id: i));
    }
    return saveShortcuts(normalized);
  }

  // Clear all shortcuts
  Future<bool> clearAllShortcuts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(storageKey);
    } catch (e) {
      print('Error clearing shortcuts: $e');
      return false;
    }
  }

  Future<List<QuickActionShortcut>> _buildDefaultWidgetShortcuts() async {
    try {
      final categoryRepo = CategoryRepository();
      final categories = await categoryRepo.getAllCategories();

      if (categories.isEmpty) {
        return [];
      }

      final defaultIncome = _findFirstCategoryByType(categories, 'income');
      final defaultExpense = _findFirstCategoryByType(categories, 'expense');

      if (defaultIncome == null || defaultExpense == null) {
        return [];
      }

      return [
        QuickActionShortcut(
          id: 0,
          type: 'income',
          shortcutType: 'category',
          categoryId: defaultIncome.id!,
          categoryName: defaultIncome.name,
          categoryIcon: defaultIncome.icon,
          description: 'Thu nhập',
        ),
        QuickActionShortcut(
          id: 1,
          type: 'expense',
          shortcutType: 'category',
          categoryId: defaultExpense.id!,
          categoryName: defaultExpense.name,
          categoryIcon: defaultExpense.icon,
          description: 'Chi tiêu',
        ),
      ];
    } catch (e) {
      print('Error building default widget shortcuts: $e');
      return [];
    }
  }

  Category? _findFirstCategoryByType(List<Category> categories, String type) {
    for (final category in categories) {
      if (category.type == type && category.id != null) {
        return category;
      }
    }
    return null;
  }

  // Check if category is used in any shortcut
  Future<bool> isCategoryUsed(int categoryId) async {
    final shortcuts = await getShortcuts();
    return shortcuts.any((s) => s.isCategoryShortcut && s.categoryId == categoryId);
  }

  // Remove shortcuts with deleted category
  Future<void> removeShortcutsWithCategory(int categoryId) async {
    final shortcuts = await getShortcuts();
    final filtered = shortcuts
        .where((s) => !(s.isCategoryShortcut && s.categoryId == categoryId))
        .toList();

    // Reassign IDs
    for (int i = 0; i < filtered.length; i++) {
      filtered[i] = filtered[i].copyWith(id: i);
    }

    await saveShortcuts(filtered);
  }
}

