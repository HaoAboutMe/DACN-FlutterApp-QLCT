import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider quản lý theme cho toàn bộ ứng dụng
class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'isDarkMode';

  ThemeMode _themeMode = ThemeMode.light;
  bool _isDarkMode = false;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadTheme();
  }

  /// Tải theme từ SharedPreferences
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? false;
    _themeMode = _isDarkMode ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  /// Chuyển đổi theme
  Future<void> toggleTheme(bool isDark) async {
    _isDarkMode = isDark;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDark);

    notifyListeners();
  }

  /// Set theme mode trực tiếp
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    _isDarkMode = mode == ThemeMode.dark;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);

    notifyListeners();
  }
}

