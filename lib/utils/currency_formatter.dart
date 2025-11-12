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
        decimalDigits: 2,
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
  /// Loại bỏ tất cả ký tự không phải số và parse thành double
  /// Xử lý đúng format vi_VN (dấu chấm là phân cách hàng nghìn)
  static double parseAmount(String input) {
    if (input.isEmpty) return 0.0;

    // Loại bỏ tất cả ký tự không phải số
    // Quan trọng: Loại bỏ dấu chấm vì trong vi_VN dấu chấm là phân cách hàng nghìn
    final cleanedInput = input.replaceAll(RegExp(r'[^\d]'), '');

    if (cleanedInput.isEmpty) return 0.0;

    // Parse thành double từ chuỗi chỉ chứa số
    final amount = double.tryParse(cleanedInput) ?? 0.0;

    return amount;
  }

  /// Format số tiền để hiển thị trong input field (có dấu phẩy ngăn cách hàng nghìn)
  static String formatForInput(double amount) {
    if (amount == 0) return '';

    // Format với dấu phẩy ngăn cách hàng nghìn (không có ký hiệu đ)
    final formatter = NumberFormat('#,###', 'vi_VN');
    return formatter.format(amount);
  }

  /// Kiểm tra xem string có phải là số tiền hợp lệ không
  static bool isValidAmount(String input) {
    if (input.isEmpty) return false;
    final amount = parseAmount(input);
    return amount > 0;
  }
}