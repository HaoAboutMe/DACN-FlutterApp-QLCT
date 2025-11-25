import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../database/repositories/repositories.dart';
import '../utils/icon_helper.dart';

/// Service quản lý Android Home Screen Widget
/// Tính toán và gửi dữ liệu từ SQLite sang Android native widget
class WidgetService {
  static final TransactionRepository _transactionRepo = TransactionRepository();
  static final UserRepository _userRepo = UserRepository();
  static final LoanRepository _loanRepo = LoanRepository();
  static final CategoryRepository _categoryRepo = CategoryRepository();

  /// Cập nhật toàn bộ dữ liệu widget
  /// Gọi hàm này khi:
  /// - App khởi động
  /// - User thêm/sửa/xoá transaction
  /// - User thêm/sửa/xoá loan
  /// - User nhấn refresh trong settings
  static Future<void> updateWidgetData() async {
    try {
      debugPrint('🔄 WidgetService: Bắt đầu cập nhật dữ liệu widget...');

      // 1. Lấy tháng/năm hiện tại
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, 1);
      final endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      // 2. Lấy tất cả transactions trong tháng
      final allTransactions = await _transactionRepo.getAllTransactions();
      final monthTransactions = allTransactions.where((trans) {
        return trans.date.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
            trans.date.isBefore(endDate.add(const Duration(seconds: 1)));
      }).toList();

      debugPrint('📊 Tìm thấy ${monthTransactions.length} transactions trong tháng ${now.month}/${now.year}');

      // 3. Tính toán thống kê
      double totalIncome = 0;
      double totalExpense = 0;
      Map<int, double> categoryExpenses = {};

      for (var trans in monthTransactions) {
        if (trans.type == 'income' || trans.type == 'debt_collected') {
          totalIncome += trans.amount;
        } else if (trans.type == 'expense' || trans.type == 'debt_paid') {
          totalExpense += trans.amount;

          // Tích lũy chi tiêu theo danh mục
          final catId = trans.categoryId;
          if (catId != null && catId > 0) {
            categoryExpenses[catId] =
                (categoryExpenses[catId] ?? 0) + trans.amount;
          }
        }
      }

      // 4. Lấy số dư hiện tại của user
      final currentUser = await _userRepo.getCurrentUser();
      final currentBalance = currentUser?.balance ?? 0;

      // 5. Lấy thống kê khoản vay (active loans only)
      final loans = await _loanRepo.getAllLoans();
      double totalLoanGiven = 0;
      double totalLoanTaken = 0;

      for (var loan in loans) {
        if (loan.status == 'active') {
          if (loan.loanType == 'lend') {
            totalLoanGiven += loan.amount;
          } else if (loan.loanType == 'borrow') {
            totalLoanTaken += loan.amount;
          }
        }
      }

      // 6. Tìm Top 3 danh mục chi tiêu nhiều nhất
      List<Map<String, dynamic>> topCategories = [];
      if (categoryExpenses.isNotEmpty) {
        final sortedCategories = categoryExpenses.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        for (int i = 0; i < min(3, sortedCategories.length); i++) {
          final categoryId = sortedCategories[i].key;
          final amount = sortedCategories[i].value;
          final category = await _categoryRepo.getCategoryById(categoryId);

          if (category != null) {
            final percent = totalExpense > 0
                ? (amount / totalExpense * 100).toStringAsFixed(1)
                : '0.0';
            final iconImage = await _generateCategoryIconBitmap(category.icon);
            topCategories.add({
              'name': category.name,
              'amount': amount,
              'percent': percent,
              'icon': category.icon,
              'category_id': category.id ?? 0,
              'type': category.type,
              'icon_image': iconImage,
            });
          }
        }
      }

      debugPrint('💰 Thu nhập: $totalIncome, Chi tiêu: $totalExpense, Số dư: $currentBalance');
      debugPrint('📈 Top categories: ${topCategories.length}');

      // 7. Lưu dữ liệu vào SharedPreferences (qua home_widget plugin)
      await HomeWidget.saveWidgetData<String>(
          'total_income', totalIncome.toStringAsFixed(0));
      await HomeWidget.saveWidgetData<String>(
          'total_expense', totalExpense.toStringAsFixed(0));
      await HomeWidget.saveWidgetData<String>(
          'current_balance', currentBalance.toStringAsFixed(0));
      await HomeWidget.saveWidgetData<String>(
          'total_loan_given', totalLoanGiven.toStringAsFixed(0));
      await HomeWidget.saveWidgetData<String>(
          'total_loan_taken', totalLoanTaken.toStringAsFixed(0));
      await HomeWidget.saveWidgetData<String>(
          'month_year', '${now.month}/${now.year}');
      await HomeWidget.saveWidgetData<String>(
          'last_update', now.toIso8601String());

      // Top categories dạng JSON string
      await HomeWidget.saveWidgetData<String>(
          'top_categories', jsonEncode(topCategories));

      // 8. Trigger cập nhật widget Android
      await HomeWidget.updateWidget(
        name: 'SpendingWidgetProvider',
        androidName: 'SpendingWidgetProvider',
        iOSName: 'SpendingWidget', // Placeholder cho iOS (chưa implement)
      );

      debugPrint('✅ Widget data updated successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Error updating widget data: $e');
      debugPrint(stackTrace.toString());

      // Lưu error state
      await HomeWidget.saveWidgetData<String>('last_error', e.toString());
    }
  }

  /// Kiểm tra widget đã được thêm vào màn hình chính chưa
  /// Returns true nếu có ít nhất 1 widget instance
  static Future<bool> isWidgetAdded() async {
    try {
      // Note: home_widget 0.6.0 không có getWidgetIds()
      // Chỉ kiểm tra xem có dữ liệu đã lưu chưa
      final lastUpdate = await HomeWidget.getWidgetData<String>('last_update');
      return lastUpdate != null && lastUpdate.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking widget status: $e');
      return false;
    }
  }

  /// Xoá toàn bộ dữ liệu widget
  static Future<void> clearWidgetData() async {
    try {
      await HomeWidget.saveWidgetData<String>('total_income', null);
      await HomeWidget.saveWidgetData<String>('total_expense', null);
      await HomeWidget.saveWidgetData<String>('current_balance', null);
      await HomeWidget.saveWidgetData<String>('total_loan_given', null);
      await HomeWidget.saveWidgetData<String>('total_loan_taken', null);
      await HomeWidget.saveWidgetData<String>('month_year', null);
      await HomeWidget.saveWidgetData<String>('last_update', null);
      await HomeWidget.saveWidgetData<String>('top_categories', null);

      await HomeWidget.updateWidget(
        name: 'SpendingWidgetProvider',
        androidName: 'SpendingWidgetProvider',
      );

      debugPrint('✅ Widget data cleared');
    } catch (e) {
      debugPrint('❌ Error clearing widget data: $e');
    }
  }

  static Future<String?> _generateCategoryIconBitmap(String iconName) async {
    try {
      final iconData = IconHelper.getCategoryIcon(iconName);
      const double canvasSize = 64;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final center = ui.Offset(canvasSize / 2, canvasSize / 2);

      final bgPaint = ui.Paint()
        ..color = const Color(0xFFFFFFFF)
        ..isAntiAlias = true;
      canvas.drawCircle(center, canvasSize / 2, bgPaint);

      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
      );
      final iconChar = String.fromCharCode(iconData.codePoint);
      textPainter.text = TextSpan(
        text: iconChar,
        style: TextStyle(
          fontSize: 36,
          fontFamily: iconData.fontFamily ?? 'MaterialIcons',
          package: iconData.fontPackage,
          color: const Color(0xFF041C32),
        ),
      );
      textPainter.layout();
      final offset = Offset(
        (canvasSize - textPainter.width) / 2,
        (canvasSize - textPainter.height) / 2,
      );
      textPainter.paint(canvas, offset);

      final picture = recorder.endRecording();
      final image = await picture.toImage(canvasSize.toInt(), canvasSize.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      return base64Encode(byteData.buffer.asUint8List());
    } catch (e, stack) {
      debugPrint('Không thể tạo icon widget: $e');
      debugPrint(stack.toString());
      return null;
    }
  }
}
