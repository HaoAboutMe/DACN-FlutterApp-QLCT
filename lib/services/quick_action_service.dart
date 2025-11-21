import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quick_action_shortcut.dart';

class QuickActionService {
  static const String _key = 'quick_action_shortcuts';
  static const int maxShortcuts = 3;

  // Get all shortcuts
  Future<List<QuickActionShortcut>> getShortcuts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_key);

      if (jsonString == null || jsonString.isEmpty) {
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

      return await prefs.setString(_key, jsonString);
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

  // Clear all shortcuts
  Future<bool> clearAllShortcuts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_key);
    } catch (e) {
      print('Error clearing shortcuts: $e');
      return false;
    }
  }

  // Check if category is used in any shortcut
  Future<bool> isCategoryUsed(int categoryId) async {
    final shortcuts = await getShortcuts();
    return shortcuts.any((s) => s.categoryId == categoryId);
  }

  // Remove shortcuts with deleted category
  Future<void> removeShortcutsWithCategory(int categoryId) async {
    final shortcuts = await getShortcuts();
    final filtered = shortcuts.where((s) => s.categoryId != categoryId).toList();

    // Reassign IDs
    for (int i = 0; i < filtered.length; i++) {
      filtered[i] = filtered[i].copyWith(id: i);
    }

    await saveShortcuts(filtered);
  }
}

