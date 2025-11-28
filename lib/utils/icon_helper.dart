import 'package:flutter/material.dart';

/// Helper class để xử lý icon từ categoryIcon string
/// Hỗ trợ cả codePoint (số) và string name (tên icon)
class IconHelper {
  // Map ánh xạ tên icon sang IconData
  static const Map<String, IconData> fallbackIcons = {
    'movie': Icons.movie,
    'shopping_bag': Icons.shopping_bag,
    'medical_services': Icons.medical_services,
    'restaurant': Icons.restaurant,
    'directions_car': Icons.directions_car,
    'more_horiz': Icons.more_horiz,
    'home': Icons.home,
    'school': Icons.school,
    'sports_soccer': Icons.sports_soccer,
    'flight': Icons.flight,
    'local_gas_station': Icons.local_gas_station,
    'phone': Icons.phone,
    'electric_bolt': Icons.electric_bolt,
    'water_drop': Icons.water_drop,
    'wifi': Icons.wifi,
    'celebration': Icons.celebration,
    'pets': Icons.pets,
    'checkroom': Icons.checkroom,
    'laptop': Icons.laptop,
    'fitness_center': Icons.fitness_center,
    'train': Icons.train,
    'local_cafe': Icons.local_cafe,
    'shopping_cart': Icons.shopping_cart,
    'local_hospital': Icons.local_hospital,
    'attach_money': Icons.attach_money,
    'card_giftcard': Icons.card_giftcard,
    'trending_up': Icons.trending_up,
    'work': Icons.work,
    'savings': Icons.savings,
    'electrical_services': Icons.electrical_services,
    'receipt': Icons.receipt,
    'receipt_long': Icons.receipt_long,
    'category': Icons.category,
    'other': Icons.category,

    // ✅ Bổ sung icon cho các loại giao dịch khoản vay / nợ
    'call_made': Icons.call_made, // Cho vay
    'call_received': Icons.call_received, // Đi vay
    'payment': Icons.payment, // Trả nợ
    'account_balance_wallet': Icons.account_balance_wallet, // Thu nợ

    // ✅ Bổ sung icon cho hóa đơn

  };

  /// Build icon từ categoryIcon string
  ///
  /// Hỗ trợ 3 dạng:
  /// - Số (codePoint): "58253" → IconData(58253, fontFamily: 'MaterialIcons')
  /// - Tên icon: "medical_services" → Icons.medical_services
  /// - Không tìm thấy → Icons.category (mặc định)
  static IconData getCategoryIcon(String categoryIcon) {
    if (categoryIcon.isEmpty) {
      return Icons.category;
    }

    // Thử parse thành số (codePoint)
    final iconCode = int.tryParse(categoryIcon);
    if (iconCode != null) {
      return IconData(iconCode, fontFamily: 'MaterialIcons');
    }

    // Nếu không phải số, tìm trong fallback map
    final iconKey = categoryIcon.toLowerCase().trim();
    if (fallbackIcons.containsKey(iconKey)) {
      return fallbackIcons[iconKey]!;
    }

    // Mặc định
    return Icons.category;
  }

  /// Build icon widget với màu và kích thước tùy chỉnh
  static Widget buildIconWidget(
    String categoryIcon, {
    Color? color,
    double size = 24,
  }) {
    return Icon(
      getCategoryIcon(categoryIcon),
      color: color,
      size: size,
    );
  }

  /// Build icon container với background color
  static Widget buildIconContainer(
    String categoryIcon, {
    required Color color,
    double size = 24,
    double padding = 10,
    double borderRadius = 10,
  }) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        getCategoryIcon(categoryIcon),
        color: color,
        size: size,
      ),
    );
  }
}

