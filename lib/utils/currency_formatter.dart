import 'package:intl/intl.dart';

class CurrencyFormatter {
  /// Định dạng số tiền theo định dạng VND
  static String formatVND(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  /// Định dạng số tiền với dấu +/- cho thu nhập/chi tiêu
  static String formatWithSign(double amount, String type) {
    final formattedAmount = formatVND(amount.abs());

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
}
