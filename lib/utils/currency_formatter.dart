import 'package:intl/intl.dart';
import '../providers/currency_provider.dart';

class CurrencyFormatter {
  static String _selectedCurrency = 'VND';
  static CurrencyProvider? _currencyProvider;

  /// Set currency provider instance
  static void setCurrencyProvider(CurrencyProvider provider) {
    _currencyProvider = provider;
    _selectedCurrency = provider.selectedCurrency;
  }

  /// Get current currency
  static String getCurrency() {
    return _selectedCurrency;
  }

  /// Set current currency
  static void setCurrency(String currency) {
    _selectedCurrency = currency;
  }

  /// Định dạng số tiền theo định dạng VND (kept for backward compatibility)
  static String formatVND(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  /// Định dạng số tiền theo currency hiện tại
  static String formatAmount(double vndAmount) {
    if (_currencyProvider == null) {
      // Fallback to VND if provider not set
      return formatVND(vndAmount);
    }

    final convertedAmount = _currencyProvider!.convertFromVND(vndAmount);
    final symbol = _currencyProvider!.currencySymbol;
    final currency = _currencyProvider!.selectedCurrency;

    if (currency == 'USD') {
      final formatter = NumberFormat.currency(
        locale: 'en_US',
        symbol: symbol,
        decimalDigits: 3,
      );
      return formatter.format(convertedAmount);
    } else {
      // VND format
      final formatter = NumberFormat.currency(
        locale: 'vi_VN',
        symbol: symbol,
        decimalDigits: 0,
      );
      return formatter.format(convertedAmount);
    }
  }

  /// Định dạng số tiền với dấu +/- cho thu nhập/chi tiêu
  static String formatWithSign(double amount, String type) {
    final formattedAmount = formatAmount(amount.abs());

    switch (type) {
      case 'income':
      case 'debt_collected':
      case 'loan_received':
        return '+$formattedAmount';
      case 'expense':
      case 'loan_given':
      case 'debt_paid':
        return '-$formattedAmount';
      default:
        return formattedAmount;
    }
  }

  /// Parse số tiền từ string input một cách an toàn
  /// Xử lý cả VND (số nguyên) và USD (có thập phân)
  static double parseAmount(String input) {
    if (input.isEmpty) return 0.0;

    // Loại bỏ spaces và currency symbols
    String cleanedInput = input.trim()
        .replaceAll(' ', '')
        .replaceAll('₫', '')
        .replaceAll('\$', '')
        .replaceAll('USD', '')
        .replaceAll('VND', '');

    if (cleanedInput.isEmpty) return 0.0;

    // Xử lý dựa trên currency hiện tại
    if (_selectedCurrency == 'USD') {
      // Cho USD: chấp nhận dấu chấm là decimal separator
      // Loại bỏ dấu phẩy (thousand separator)
      cleanedInput = cleanedInput.replaceAll(',', '');

      // Kiểm tra format USD hợp lệ (chỉ có 1 dấu chấm)
      final dotCount = cleanedInput.split('.').length - 1;
      if (dotCount > 1) return 0.0;

      return double.tryParse(cleanedInput) ?? 0.0;
    } else {
      // Cho VND: dấu chấm là thousand separator, không có decimal
      // Loại bỏ dấu chấm và dấu phẩy (thousand separators)
      cleanedInput = cleanedInput.replaceAll(RegExp(r'[^\d]'), '');

      if (cleanedInput.isEmpty) return 0.0;
      return double.tryParse(cleanedInput) ?? 0.0;
    }
  }

  /// Format số tiền để hiển thị trong input field
  /// Giữ nguyên số thập phân cho USD, format VND như cũ
  static String formatForInput(double amount) {
    if (amount == 0) return '';

    if (_selectedCurrency == 'USD') {
      // Cho USD: hiển thị với 3 chữ số thập phân, không có thousand separator trong input
      return amount.toStringAsFixed(3);
    } else {
      // Cho VND: format với dấu phẩy ngăn cách hàng nghìn (không có ký hiệu đ)
      final formatter = NumberFormat('#,###', 'vi_VN');
      return formatter.format(amount);
    }
  }

  /// Format số tiền với độ chính xác cao cho edit screen
  /// Giữ nguyên tất cả chữ số thập phân có nghĩa
  static String formatForInputWithPrecision(double amount) {
    if (amount == 0) return '';

    if (_selectedCurrency == 'USD') {
      // Cho USD: hiển thị đến 6 chữ số thập phân nhưng loại bỏ các số 0 thừa
      String formatted = amount.toStringAsFixed(6);
      // Loại bỏ các số 0 thừa ở cuối
      formatted = formatted.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
      return formatted;
    } else {
      // Cho VND: format với dấu phẩy ngăn cách hàng nghìn
      final formatter = NumberFormat('#,###', 'vi_VN');
      return formatter.format(amount);
    }
  }

  /// Kiểm tra xem string có phải là số tiền hợp lệ không
  static bool isValidAmount(String input) {
    if (input.isEmpty) return false;
    final amount = parseAmount(input);
    return amount > 0;
  }
}