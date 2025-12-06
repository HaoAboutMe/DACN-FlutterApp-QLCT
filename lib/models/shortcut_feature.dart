import 'package:flutter/material.dart';
import '../utils/icon_helper.dart';

enum ShortcutFeatureAction {
  addExpense,
  addIncome,
  scanReceipt,
  viewBudgets,
  openStatistics,
  openLoans,
}

class ShortcutFeature {
  final String id;
  final String title;
  final String subtitle;
  final String iconCode;
  final Color color;
  final ShortcutFeatureAction action;

  const ShortcutFeature({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.iconCode,
    required this.color,
    required this.action,
  });

  IconData get iconData => IconHelper.getCategoryIcon(iconCode);
}

class ShortcutFeatureCatalog {
  ShortcutFeatureCatalog._();

  static String _iconCode(IconData icon) => icon.codePoint.toString();

  static final List<ShortcutFeature> features = [
    ShortcutFeature(
      id: 'add_expense',
      title: 'Thêm chi tiêu',
      subtitle: 'Ghi nhanh một khoản chi',
      iconCode: _iconCode(Icons.trending_down),
      color: const Color(0xFFFF6B6B),
      action: ShortcutFeatureAction.addExpense,
    ),
    ShortcutFeature(
      id: 'add_income',
      title: 'Thêm thu nhập',
      subtitle: 'Cập nhật khoản thu mới',
      iconCode: _iconCode(Icons.trending_up),
      color: const Color(0xFF4CAF50),
      action: ShortcutFeatureAction.addIncome,
    ),
    ShortcutFeature(
      id: 'scan_receipt',
      title: 'Quét hóa đơn',
      subtitle: 'Nhận diện số tiền từ bill',
      iconCode: _iconCode(Icons.document_scanner),
      color: const Color(0xFF7E57C2),
      action: ShortcutFeatureAction.scanReceipt,
    ),
    ShortcutFeature(
      id: 'view_budgets',
      title: 'Xem ngân sách',
      subtitle: 'Theo dõi tiến độ chi tiêu',
      iconCode: _iconCode(Icons.account_balance_wallet),
      color: const Color(0xFF00BCD4),
      action: ShortcutFeatureAction.viewBudgets,
    ),
    ShortcutFeature(
      id: 'open_statistics',
      title: 'Biểu đồ thống kê',
      subtitle: 'So sánh thu chi theo tháng',
      iconCode: _iconCode(Icons.insights),
      color: const Color(0xFF29B6F6),
      action: ShortcutFeatureAction.openStatistics,
    ),
    ShortcutFeature(
      id: 'open_loans',
      title: 'Sổ vay & cho vay',
      subtitle: 'Theo dõi khoản vay hiện tại',
      iconCode: _iconCode(Icons.account_balance),
      color: const Color(0xFFFFB74D),
      action: ShortcutFeatureAction.openLoans,
    ),
  ];

  static ShortcutFeature? findById(String? id) {
    if (id == null) return null;
    try {
      return features.firstWhere((feature) => feature.id == id);
    } catch (_) {
      return null;
    }
  }
}
