/// Model cho phím tắt nhanh tùy chỉnh
class QuickActionShortcut {
  final int? id; // Local ID (0, 1, 2)
  final String type; // 'income' hoặc 'expense'
  final int categoryId;
  final String categoryName;
  final String categoryIcon;
  final String? description; // Mô tả tự động điền

  QuickActionShortcut({
    this.id,
    required this.type,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    this.description,
  });

  // Convert to JSON for SharedPreferences
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'categoryIcon': categoryIcon,
      'description': description,
    };
  }

  // Create from JSON
  factory QuickActionShortcut.fromJson(Map<String, dynamic> json) {
    return QuickActionShortcut(
      id: json['id'] as int?,
      type: json['type'] as String,
      categoryId: json['categoryId'] as int,
      categoryName: json['categoryName'] as String,
      categoryIcon: json['categoryIcon'] as String,
      description: json['description'] as String?,
    );
  }

  QuickActionShortcut copyWith({
    int? id,
    String? type,
    int? categoryId,
    String? categoryName,
    String? categoryIcon,
    String? description,
  }) {
    return QuickActionShortcut(
      id: id ?? this.id,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryIcon: categoryIcon ?? this.categoryIcon,
      description: description ?? this.description,
    );
  }
}

