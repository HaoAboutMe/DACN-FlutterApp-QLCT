import 'package:flutter/foundation.dart';

@immutable
class User {
  /// ID của người dùng (tự động tăng trong database)
  final int? id;

  /// Tên người dùng
  final String name;

  /// Số dư tài khoản hiện tại (đơn vị: VND)
  final double balance;

  /// Thời gian tạo tài khoản
  final DateTime createdAt;

  /// Thời gian cập nhật cuối cùng
  final DateTime updatedAt;

  const User({
    this.id,
    required this.name,
    required this.balance,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Tạo đối tượng User từ Map (sử dụng khi đọc từ database)
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int?,
      name: map['name'] as String,
      balance: (map['balance'] as num).toDouble(),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  /// Chuyển đổi đối tượng User thành Map (sử dụng khi lưu vào database)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'balance': balance,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Tạo bản sao của User với các giá trị được cập nhật
  User copyWith({
    int? id,
    String? name,
    double? balance,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.id == id &&
        other.name == name &&
        other.balance == balance &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        balance.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }

  @override
  String toString() {
    return 'User(id: $id, name: $name, balance: $balance, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}
