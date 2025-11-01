import 'package:flutter/foundation.dart';

@immutable
class Budget {
  /// ID của ngân sách (tự động tăng trong database)
  final int? id;

  /// Số tiền ngân sách
  final double amount;

  /// ID danh mục liên kết (null nếu là ngân sách tổng)
  final int? categoryId;

  /// Ngày bắt đầu ngân sách
  final DateTime startDate;

  /// Ngày kết thúc ngân sách
  final DateTime endDate;

  /// Thời gian tạo ngân sách
  final DateTime createdAt;

  const Budget({
    this.id,
    required this.amount,
    this.categoryId,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
  });

  /// Tạo đối tượng Budget từ Map (sử dụng khi đọc từ database)
  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['category_id'] as int?,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Tạo Budget tổng (overall budget) - không gắn với danh mục cụ thể
  /// Dùng categoryId = null để đánh dấu là ngân sách tổng
  factory Budget.overall({
    int? id,
    required double amount,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return Budget(
      id: id,
      amount: amount,
      categoryId: null,
      startDate: startDate,
      endDate: endDate,
      createdAt: DateTime.now(),
    );
  }

  /// Chuyển đổi đối tượng Budget thành Map (sử dụng khi lưu vào database)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'category_id': categoryId,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Tạo bản sao của Budget với các giá trị được cập nhật
  Budget copyWith({
    int? id,
    double? amount,
    int? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdAt,
  }) {
    return Budget(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Kiểm tra xem ngân sách có đang hoạt động không
  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  /// Kiểm tra xem có phải ngân sách tổng không (không gắn với danh mục cụ thể)
  bool get isOverallBudget => categoryId == null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Budget &&
        other.id == id &&
        other.amount == amount &&
        other.categoryId == categoryId &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        amount.hashCode ^
        categoryId.hashCode ^
        startDate.hashCode ^
        endDate.hashCode ^
        createdAt.hashCode;
  }

  @override
  String toString() {
    return 'Budget(id: $id, amount: $amount, categoryId: $categoryId, startDate: $startDate, endDate: $endDate, createdAt: $createdAt)';
  }
}
