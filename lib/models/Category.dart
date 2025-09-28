import 'package:flutter/foundation.dart';

@immutable
class Category {
  /// ID của danh mục (tự động tăng trong database)
  final int? id;

  /// Tên danh mục (ví dụ: "Ăn uống", "Di chuyển", "Lương")
  final String name;

  /// Biểu tượng của danh mục (icon name hoặc emoji)
  final String icon;

  /// Loại danh mục: "income" (thu nhập) hoặc "expense" (chi tiêu)
  final String type;

  /// Thời gian tạo danh mục
  final DateTime createdAt;

  const Category({
    this.id,
    required this.name,
    required this.icon,
    required this.type,
    required this.createdAt,
  });

  /// Tạo đối tượng Category từ Map (sử dụng khi đọc từ database)
  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      icon: map['icon'] as String,
      type: map['type'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  /// Chuyển đổi đối tượng Category thành Map (sử dụng khi lưu vào database)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Tạo bản sao của Category với các giá trị được cập nhật
  Category copyWith({
    int? id,
    String? name,
    String? icon,
    String? type,
    DateTime? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Kiểm tra xem danh mục có phải là thu nhập không
  bool get isIncome => type == 'income';

  /// Kiểm tra xem danh mục có phải là chi tiêu không
  bool get isExpense => type == 'expense';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Category &&
        other.id == id &&
        other.name == name &&
        other.icon == icon &&
        other.type == type &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        icon.hashCode ^
        type.hashCode ^
        createdAt.hashCode;
  }

  @override
  String toString() {
    return 'Category(id: $id, name: $name, icon: $icon, type: $type, createdAt: $createdAt)';
  }
}
