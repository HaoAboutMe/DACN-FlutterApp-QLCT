/// Model cho phím tắt nhanh tùy chỉnh
///
/// Hỗ trợ 2 chế độ:
/// 1. Template Mode (amount = null): Dẫn đến Add Transaction với thông tin đã điền sẵn
/// 2. Quick Add Mode (amount != null): Thêm trực tiếp transaction không cần màn hình trung gian
class QuickActionShortcut {
  final int? id; // Local ID (0, 1, 2)
  final String type; // 'income' hoặc 'expense'
  final int categoryId;
  final String categoryName;
  final String categoryIcon;
  final String? description; // Mô tả tùy chỉnh (nếu null, dùng categoryName)
  final double? amount; // Số tiền (nếu null = Template Mode, nếu có giá trị = Quick Add Mode)

  QuickActionShortcut({
    this.id,
    required this.type,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    this.description,
    this.amount,
  });

  /// Lấy mô tả hiển thị: Ưu tiên description tùy chỉnh, không có thì dùng categoryName
  String get displayDescription => description?.isNotEmpty == true ? description! : categoryName;

  /// Kiểm tra có phải Quick Add Mode (có số tiền) hay không
  bool get isQuickAddMode => amount != null && amount! > 0;

  /// Kiểm tra có phải Template Mode (không có số tiền) hay không
  bool get isTemplateMode => !isQuickAddMode;

  // Convert to JSON for SharedPreferences
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'categoryIcon': categoryIcon,
      'description': description,
      'amount': amount,
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
      amount: json['amount'] != null ? (json['amount'] as num).toDouble() : null,
    );
  }

  QuickActionShortcut copyWith({
    int? id,
    String? type,
    int? categoryId,
    String? categoryName,
    String? categoryIcon,
    String? description,
    double? amount,
    bool clearAmount = false, // Flag để clear amount về null
  }) {
    return QuickActionShortcut(
      id: id ?? this.id,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryIcon: categoryIcon ?? this.categoryIcon,
      description: description ?? this.description,
      amount: clearAmount ? null : (amount ?? this.amount),
    );
  }
}

