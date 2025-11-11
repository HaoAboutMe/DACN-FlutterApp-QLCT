import '../models/category.dart';

/// Class quản lý danh sách các danh mục mặc định của ứng dụng
/// Sử dụng để khởi tạo danh mục khi database trống
class DefaultCategories {
  /// Không cho phép khởi tạo instance của class này
  DefaultCategories._();

  /// Danh sách các danh mục mặc định
  /// Bao gồm các danh mục thu nhập và chi tiêu phổ biến
  static List<Category> getDefaultCategories() {
    final now = DateTime.now();

    return [
      // Các danh mục chi tiêu (expense)
      Category(
        name: 'Ăn uống',
        icon: 'restaurant',
        type: 'expense',
        createdAt: now,
      ),
      Category(
        name: 'Mua sắm',
        icon: 'shopping_bag',
        type: 'expense',
        createdAt: now,
      ),
      Category(
        name: 'Đi lại',
        icon: 'directions_car',
        type: 'expense',
        createdAt: now,
      ),
      Category(
        name: 'Giải trí',
        icon: 'movie',
        type: 'expense',
        createdAt: now,
      ),
      Category(
        name: 'Y tế',
        icon: 'medical_services',
        type: 'expense',
        createdAt: now,
      ),
      Category(
        name: 'Khác',
        icon: 'more_horiz',
        type: 'expense',
        createdAt: now,
      ),

      // Các danh mục thu nhập (income)
      Category(
        name: 'Lương',
        icon: 'attach_money',
        type: 'income',
        createdAt: now,
      ),
      Category(
        name: 'Thưởng',
        icon: 'card_giftcard',
        type: 'income',
        createdAt: now,
      ),
      Category(
        name: 'Đầu tư',
        icon: 'trending_up',
        type: 'income',
        createdAt: now,
      ),
    ];
  }
}

