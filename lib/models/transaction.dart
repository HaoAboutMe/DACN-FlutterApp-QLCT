import 'package:flutter/foundation.dart';
import '../utils/currency_formatter.dart';

@immutable
class Transaction {
  /// ID của giao dịch (tự động tăng trong database)
  final int? id;

  /// Số tiền giao dịch (đơn vị: VND)
  final double amount;

  /// Mô tả chi tiết về giao dịch
  final String description;

  /// Ngày thực hiện giao dịch
  final DateTime date;

  /// ID của danh mục liên quan (nullable)
  final int? categoryId;

  /// ID của khoản vay/nợ liên quan (nullable)
  final int? loanId;

  /// Loại giao dịch: "income", "expense", "loan_given", "loan_received", "debt_paid", "debt_collected"
  final String type;

  /// Thời gian tạo giao dịch
  final DateTime createdAt;

  /// Thời gian cập nhật cuối cùng
  final DateTime updatedAt;

  const Transaction({
    this.id,
    required this.amount,
    required this.description,
    required this.date,
    this.categoryId,
    this.loanId,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Tạo đối tượng Transaction từ Map (sử dụng khi đọc từ database)
  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String,
      date: DateTime.parse(map['date'] as String),
      categoryId: map['categoryId'] as int?,
      loanId: map['loanId'] as int?,
      type: map['type'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  /// Chuyển đổi đối tượng Transaction thành Map (sử dụng khi lưu vào database)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'description': description,
      'date': date.toIso8601String(),
      'categoryId': categoryId,
      'loanId': loanId,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Tạo bản sao của Transaction với các giá trị được cập nhật
  Transaction copyWith({
    int? id,
    double? amount,
    String? description,
    DateTime? date,
    int? categoryId,
    int? loanId,
    String? type,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      date: date ?? this.date,
      categoryId: categoryId ?? this.categoryId,
      loanId: loanId ?? this.loanId,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Kiểm tra xem giao dịch có phải là thu nhập không
  bool get isIncome => type == 'income';

  /// Kiểm tra xem giao dịch có phải là chi tiêu không
  bool get isExpense => type == 'expense';

  /// Kiểm tra xem giao dịch có liên quan đến vay/nợ không
  bool get isLoanRelated => ['loan_given', 'loan_received', 'debt_paid', 'debt_collected'].contains(type);

  /// Định dạng số tiền theo định dạng Việt Nam
  String get formattedAmount {
    String amountStr = amount.toStringAsFixed(0);

    // Add thousand separators
    String result = '';
    int count = 0;
    for (int i = amountStr.length - 1; i >= 0; i--) {
      if (count == 3) {
        result = '.$result';
        count = 0;
      }
      result = '${amountStr[i]}$result';
      count++;
    }

    // Use CurrencyFormatter for proper currency formatting
    return CurrencyFormatter.formatAmount(amount);
  }

  /// Lấy tên hiển thị của loại giao dịch bằng tiếng Việt
  String get displayType {
    switch (type) {
      case 'income':
        return 'Thu nhập';
      case 'expense':
        return 'Chi tiêu';
      case 'loan_given':
        return 'Cho vay';
      case 'loan_received':
        return 'Đi vay';
      case 'debt_paid':
        return 'Trả nợ';
      case 'debt_collected':
        return 'Thu nợ';
      default:
        return 'Không xác định';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Transaction &&
        other.id == id &&
        other.amount == amount &&
        other.description == description &&
        other.date == date &&
        other.categoryId == categoryId &&
        other.loanId == loanId &&
        other.type == type &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        amount.hashCode ^
        description.hashCode ^
        date.hashCode ^
        categoryId.hashCode ^
        loanId.hashCode ^
        type.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }

  @override
  String toString() {
    return 'Transaction(id: $id, amount: $amount, description: $description, date: $date, categoryId: $categoryId, loanId: $loanId, type: $type, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}
