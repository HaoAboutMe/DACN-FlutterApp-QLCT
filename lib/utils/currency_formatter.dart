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