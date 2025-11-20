import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/currency_formatter.dart';

/// Provider quản lý currency cho toàn bộ ứng dụng
class CurrencyProvider extends ChangeNotifier {
  static const String _currencyKey = 'selectedCurrency'; //Đây là key để lưu currency trong SharedPreferences
  static const String _exchangeRateKey = 'exchangeRate'; //Đây là key để lưu exchange rate trong SharedPreferences
  static const String _lastFetchKey = 'lastExchangeRateFetch'; //Đây là key để lưu thời gian fetch lần cuối trong SharedPreferences

  static const Duration _cacheExpiry = Duration(hours: 12);

  /// Currency hiện tại (mặc định VND)
  String _selectedCurrency = 'VND';
  double _exchangeRate = 25000.0; // 1 USD = 25,000 VND đặt default
  DateTime? _lastFetch; // Thời gian fetch lần cuối

  String get selectedCurrency => _selectedCurrency;
  double get exchangeRate => _exchangeRate;

  CurrencyProvider() {
    _loadCurrency();
  }

  /// Tải currency và exchange rate từ SharedPreferences
  Future<void> _loadCurrency() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _selectedCurrency = prefs.getString(_currencyKey) ?? 'VND'; // Mặc định VND nếu có thay dổi thì lấy thay đổi, không thì lấy mặc định

      /// cho exchange rate bằng giá trị đã lưu
      final cachedRate = prefs.getDouble(_exchangeRateKey);
      if (cachedRate != null) {
        _exchangeRate = cachedRate;
      }

      /// cho last fetch time bằng giá trị đã lưu
      final lastFetchMillis = prefs.getInt(_lastFetchKey);
      if (lastFetchMillis != null) {
        _lastFetch = DateTime.fromMillisecondsSinceEpoch(lastFetchMillis); // Chuyển từ millis về DateTime
      }

      // Fetch new rate if cache is expired or doesn't exist
      await _fetchExchangeRateIfNeeded();

      // ✅ IMPORTANT: Update CurrencyFormatter after loading currency settings
      // This ensures CurrencyFormatter uses the correct currency from SharedPreferences
      await _updateCurrencyFormatter();

      notifyListeners();
    } catch (e) {
      print('Error loading currency settings: $e');
      // Keep default values and try to fetch fresh rate
      await _fetchExchangeRate();

      // ✅ IMPORTANT: Update CurrencyFormatter even on error
      await _updateCurrencyFormatter();

      notifyListeners();
    }
  }

  /// Update CurrencyFormatter with current provider settings
  Future<void> _updateCurrencyFormatter() async {
    try {
      CurrencyFormatter.setCurrencyProvider(this);
      print('✅ CurrencyFormatter updated with currency: $_selectedCurrency');
    } catch (e) {
      print('Error updating CurrencyFormatter: $e');
    }
  }

  /// Set currency và lưu vào SharedPreferences
  Future<void> setCurrency(String currency) async {
    debugPrint('🔄 CurrencyProvider.setCurrency() called with: $currency (current: $_selectedCurrency)');

    if (_selectedCurrency != currency) {
      _selectedCurrency = currency;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currencyKey, currency);
      debugPrint('💾 Saved currency to SharedPreferences: $currency');

      await _fetchExchangeRateIfNeeded();

      // ✅ Update CurrencyFormatter when currency changes
      await _updateCurrencyFormatter();

      notifyListeners();
      debugPrint('✅ Currency updated and listeners notified: $_selectedCurrency');
    } else {
      debugPrint('⚠️ Currency already set to: $currency, skipping update');
    }
  }

  /// Fetch exchange rate nếu cần thiết
  Future<void> _fetchExchangeRateIfNeeded() async {
    final now = DateTime.now();

    // Check if we need to fetch new rate
    if (_lastFetch == null || now.difference(_lastFetch!) > _cacheExpiry) {
      await _fetchExchangeRate();
    }
  }

  /// Fetch exchange rate từ API
  Future<void> _fetchExchangeRate() async {
    // lấy API từ open.er-api.com (theo dõi tỷ giá hối đoái mới nhất)
    try {
      final response = await http.get(
        Uri.parse('https://open.er-api.com/v6/latest/VND'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      // Kiểm tra response
      if (response.statusCode == 200) {
        final data = json.decode(response.body); // Giải mã JSON

        if (data['result'] == 'success' && data['rates'] != null && data['rates']['USD'] != null) {
          final rate = (data['rates']['USD'] as num).toDouble(); // Lấy tỷ giá VND to USD

          _exchangeRate = 1 / rate; // Chuyển đổi sang USD từ VND
          _lastFetch = DateTime.now();

          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble(_exchangeRateKey, _exchangeRate); // Lưu exchange rate
          await prefs.setInt(_lastFetchKey, _lastFetch!.millisecondsSinceEpoch); // Lưu thời gian fetch

          print('✅ Exchange rate updated: 1 USD = ${_exchangeRate.toStringAsFixed(0)} VND'); //Debug log
        } else {
          throw Exception('Invalid API response format');
        }
      }
    } catch (e) {
      print('Failed to fetch exchange rate: $e');
      print('Using cached/fallback rate: 1 USD = ${_exchangeRate.toStringAsFixed(0)} VND');
    }
  }

  /// Convert amount từ VND sang currency hiện tại
  double convertFromVND(double vndAmount) {
    if (_selectedCurrency == 'VND') {
      return vndAmount;
    } else {
      // Convert VND to USD
      return vndAmount / _exchangeRate;
    }
  }

  /// Convert amount từ currency hiện tại về VND
  double convertToVND(double amount) {
    if (_selectedCurrency == 'VND') {
      return amount;
    } else {
      // Convert USD to VND
      return amount * _exchangeRate;
    }
  }

  /// Get currency symbol
  String get currencySymbol {
    switch (_selectedCurrency) {
      case 'USD':
        return '\$';
      case 'VND':
      default:
        return '₫';
    }
  }

  /// Get currency name
  String get currencyName {
    switch (_selectedCurrency) {
      case 'USD':
        return 'USD (\$)';
      case 'VND':
      default:
        return 'VND (₫)';
    }
  }

  /// Force refresh exchange rate
  Future<void> refreshExchangeRate() async {
    await _fetchExchangeRate();
    notifyListeners();
  }
}
