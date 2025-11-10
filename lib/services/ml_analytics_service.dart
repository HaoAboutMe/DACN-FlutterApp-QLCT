import 'dart:developer';
import 'dart:math' as math;
import '../database/database_helper.dart';
import '../models/transaction.dart';
import '../models/ml_prediction.dart';

/// Service xử lý các thuật toán Machine Learning nhẹ cho phân tích chi tiêu
class MLAnalyticsService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ==================== DỰ ĐOÁN CHI TIÊU ====================

  /// Dự đoán chi tiêu tháng tới sử dụng Linear Regression đơn giản
  Future<SpendingPrediction> predictNextMonthSpending({
    required DateTime currentMonth,
    int monthsToAnalyze = 6,
  }) async {
    try {
      // Lấy dữ liệu chi tiêu các tháng trước
      final monthlyData = await _getMonthlySpendingHistory(
        currentMonth: currentMonth,
        monthsBack: monthsToAnalyze,
      );

      if (monthlyData.isEmpty) {
        return SpendingPrediction(
          month: _formatMonth(DateTime(currentMonth.year, currentMonth.month + 1)),
          predictedAmount: 0,
          confidence: 0,
          trend: 'stable',
          changeRate: 0,
        );
      }

      // Nếu chỉ có 1 tháng dữ liệu, dùng trung bình đơn giản
      if (monthlyData.length == 1) {
        return SpendingPrediction(
          month: _formatMonth(DateTime(currentMonth.year, currentMonth.month + 1)),
          predictedAmount: monthlyData[0]['amount'] as double,
          confidence: 0.5,
          trend: 'stable',
          changeRate: 0,
        );
      }

      // Áp dụng Linear Regression
      final prediction = _linearRegression(monthlyData);

      // Tính xu hướng và tốc độ thay đổi
      final trend = _calculateTrend(monthlyData);
      final changeRate = _calculateChangeRate(monthlyData);
      final confidence = _calculateConfidence(monthlyData);

      final nextMonth = DateTime(currentMonth.year, currentMonth.month + 1);

      return SpendingPrediction(
        month: _formatMonth(nextMonth),
        predictedAmount: math.max(0, prediction),
        confidence: confidence,
        trend: trend,
        changeRate: changeRate,
      );
    } catch (e) {
      log('Lỗi dự đoán chi tiêu: $e');
      rethrow;
    }
  }

  /// Linear Regression đơn giản
  double _linearRegression(List<Map<String, dynamic>> data) {
    final n = data.length;

    // Chuẩn bị dữ liệu: x = tháng (0, 1, 2...), y = chi tiêu
    final x = List.generate(n, (i) => i.toDouble());
    final y = data.map((e) => e['amount'] as double).toList();

    // Tính các giá trị cần thiết
    final sumX = x.reduce((a, b) => a + b);
    final sumY = y.reduce((a, b) => a + b);
    final sumXY = List.generate(n, (i) => x[i] * y[i]).reduce((a, b) => a + b);
    final sumX2 = x.map((e) => e * e).reduce((a, b) => a + b);

    // Tính slope (độ dốc) và intercept
    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    final intercept = (sumY - slope * sumX) / n;

    // Dự đoán cho tháng tiếp theo
    final nextX = n.toDouble();
    final prediction = slope * nextX + intercept;

    // Áp dụng Exponential Smoothing để làm mượt
    final lastActual = y.last;
    final alpha = 0.3; // Hệ số smoothing
    final smoothedPrediction = alpha * prediction + (1 - alpha) * lastActual;

    return smoothedPrediction;
  }


  /// Tính xu hướng (trend)
  String _calculateTrend(List<Map<String, dynamic>> data) {
    if (data.length < 2) return 'stable';

    final amounts = data.map((e) => e['amount'] as double).toList();
    final recent = amounts.sublist(math.max(0, amounts.length - 3));

    if (recent.length < 2) return 'stable';

    var increasing = 0;
    var decreasing = 0;

    for (var i = 1; i < recent.length; i++) {
      if (recent[i] > recent[i - 1] * 1.05) increasing++;
      if (recent[i] < recent[i - 1] * 0.95) decreasing++;
    }

    if (increasing > decreasing) return 'increasing';
    if (decreasing > increasing) return 'decreasing';
    return 'stable';
  }

  /// Tính tốc độ thay đổi (%)
  double _calculateChangeRate(List<Map<String, dynamic>> data) {
    if (data.length < 2) return 0;

    final amounts = data.map((e) => e['amount'] as double).toList();
    final last = amounts.last;
    final previous = amounts[amounts.length - 2];

    if (previous == 0) return 0;

    return ((last - previous) / previous) * 100;
  }

  /// Tính độ tin cậy của dự đoán
  double _calculateConfidence(List<Map<String, dynamic>> data) {
    if (data.length < 3) return 0.5;

    final amounts = data.map((e) => e['amount'] as double).toList();

    // Tính độ lệch chuẩn
    final mean = amounts.reduce((a, b) => a + b) / amounts.length;
    final variance = amounts.map((e) => math.pow(e - mean, 2)).reduce((a, b) => a + b) / amounts.length;
    final stdDev = math.sqrt(variance);

    // Coefficient of Variation
    final cv = mean > 0 ? stdDev / mean : 1.0;

    // Độ tin cậy cao khi CV thấp (dữ liệu ổn định)
    final confidence = math.max(0.3, math.min(0.95, 1.0 - cv));

    return confidence.toDouble();
  }

  /// Lấy lịch sử chi tiêu theo tháng
  Future<List<Map<String, dynamic>>> _getMonthlySpendingHistory({
    required DateTime currentMonth,
    required int monthsBack,
  }) async {
    final results = <Map<String, dynamic>>[];

    for (var i = monthsBack - 1; i >= 0; i--) {
      final targetMonth = DateTime(currentMonth.year, currentMonth.month - i);
      final startDate = DateTime(targetMonth.year, targetMonth.month, 1);
      final endDate = DateTime(targetMonth.year, targetMonth.month + 1, 0, 23, 59, 59);

      final transactions = await _dbHelper.getTransactionsByDateRange(startDate, endDate);

      // Tính tổng chi tiêu (chỉ expense)
      final totalExpense = transactions
          .where((t) => t.type == 'expense')
          .fold(0.0, (sum, t) => sum + t.amount);

      results.add({
        'month': targetMonth,
        'amount': totalExpense,
      });
    }

    // Lọc bỏ các tháng không có dữ liệu
    return results.where((e) => e['amount'] as double > 0).toList();
  }

  // ==================== PHÂN TÍCH THÓI QUEN ====================

  /// Phân tích thói quen chi tiêu
  Future<SpendingHabit> analyzeSpendingHabits({
    required DateTime currentMonth,
  }) async {
    final startDate = DateTime(currentMonth.year, currentMonth.month, 1);
    final endDate = DateTime(currentMonth.year, currentMonth.month + 1, 0, 23, 59, 59);

    final transactions = await _dbHelper.getTransactionsByDateRange(startDate, endDate);
    final expenses = transactions.where((t) => t.type == 'expense').toList();

    if (expenses.isEmpty) {
      return const SpendingHabit(
        topSpendingDays: ['Chưa có dữ liệu'],
        topCategories: [],
        preferredTime: 'Chưa có dữ liệu',
        avgDailySpending: 0,
        spendingStyle: 'Chưa xác định',
      );
    }

    // ===== PHÂN TÍCH NGÀY CHI TIÊU NHIỀU NHẤT (Lấy nhiều ngày nếu gần bằng nhau) =====
    final daySpending = <String, double>{};
    for (var expense in expenses) {
      final dayName = _getDayName(expense.date.weekday);
      daySpending[dayName] = (daySpending[dayName] ?? 0) + expense.amount;
    }

    final topSpendingDays = <String>[];
    if (daySpending.isNotEmpty) {
      // Tìm ngày chi tiêu cao nhất
      final maxSpending = daySpending.values.reduce(math.max);
      final threshold = maxSpending * 0.9; // Lấy các ngày >= 90% mức cao nhất

      // Lấy tất cả ngày có chi tiêu >= threshold
      topSpendingDays.addAll(
          daySpending.entries
              .where((e) => e.value >= threshold)
              .map((e) => e.key)
              .toList()
      );
    }

    if (topSpendingDays.isEmpty) {
      topSpendingDays.add('Chưa xác định');
    }

    // ===== PHÂN TÍCH DANH MỤC CHI TIÊU HÀNG ĐẦU (Top 2-3 categories) =====
    final categorySpending = <int, double>{};
    for (var expense in expenses) {
      if (expense.categoryId != null) {
        categorySpending[expense.categoryId!] =
            (categorySpending[expense.categoryId!] ?? 0) + expense.amount;
      }
    }

    final totalSpending = expenses.fold(0.0, (sum, e) => sum + e.amount);
    final topCategories = <TopCategoryInfo>[];

    if (categorySpending.isNotEmpty) {
      // Sắp xếp theo số tiền giảm dần
      final sortedCategories = categorySpending.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Lấy top 3 hoặc các danh mục có giá trị >= 10% tổng chi tiêu
      final minThreshold = totalSpending * 0.1; // Ít nhất 10% tổng chi
      var count = 0;

      for (var entry in sortedCategories) {
        if (count >= 3 && entry.value < minThreshold) break; // Tối đa 3, trừ khi có nhiều hơn đạt 10%

        final category = await _dbHelper.getCategoryById(entry.key);
        if (category != null) {
          final percentage = (entry.value / totalSpending) * 100;

          // Tạo màu sắc động dựa trên tên danh mục
          final color = _generateCategoryColor(category.name);

          topCategories.add(TopCategoryInfo(
            name: category.name,
            icon: category.icon,
            color: color,
            percentage: percentage,
            amount: entry.value,
          ));

          count++;
          if (count >= 3) break; // Giới hạn tối đa 3 danh mục
        }
      }
    }

    // ===== PHÂN TÍCH THỜI GIAN TRONG NGÀY =====
    final timeSpending = <String, double>{};
    for (var expense in expenses) {
      final hour = expense.date.hour;
      String timeOfDay;
      if (hour >= 6 && hour < 12) {
        timeOfDay = 'Buổi sáng';
      } else if (hour >= 12 && hour < 18) {
        timeOfDay = 'Buổi chiều';
      } else if (hour >= 18 && hour < 22) {
        timeOfDay = 'Buổi tối';
      } else {
        timeOfDay = 'Đêm khuya';
      }
      timeSpending[timeOfDay] = (timeSpending[timeOfDay] ?? 0) + expense.amount;
    }

    final preferredTime = timeSpending.isNotEmpty
        ? timeSpending.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : 'Chưa xác định';

    // ===== TÍNH CHI TIÊU TRUNG BÌNH HÀNG NGÀY =====
    final daysInMonth = DateTime(currentMonth.year, currentMonth.month + 1, 0).day;
    final avgDailySpending = totalSpending / daysInMonth;

    // ===== XÁC ĐỊNH PHONG CÁCH CHI TIÊU =====
    final spendingStyle = _determineSpendingStyle(expenses, currentMonth);

    return SpendingHabit(
      topSpendingDays: topSpendingDays,
      topCategories: topCategories,
      preferredTime: preferredTime,
      avgDailySpending: avgDailySpending,
      spendingStyle: spendingStyle,
    );
  }

  /// Xác định phong cách chi tiêu
  String _determineSpendingStyle(List<Transaction> expenses, DateTime month) {
    if (expenses.isEmpty) return 'Chưa xác định';

    final totalSpending = expenses.fold(0.0, (sum, e) => sum + e.amount);
    final avgTransaction = totalSpending / expenses.length;

    // Lấy dữ liệu 3 tháng trước để so sánh
    final previousMonths = <double>[];
    for (var i = 1; i <= 3; i++) {
      // Giả định logic để lấy dữ liệu các tháng trước (có thể cải thiện)
      previousMonths.add(totalSpending); // Placeholder
    }

    // Phân loại dựa trên giao dịch trung bình và tần suất
    if (avgTransaction < 100000 && expenses.length < 20) {
      return 'Tiết kiệm';
    } else if (avgTransaction > 500000 || expenses.length > 50) {
      return 'Thoải mái';
    } else {
      return 'Cân đối';
    }
  }

  // ==================== CẢNH BÁO NGÂN SÁCH ====================

  /// Phát hiện cảnh báo vượt ngân sách
  Future<List<BudgetAlert>> detectBudgetAlerts({
    required DateTime currentMonth,
  }) async {
    final alerts = <BudgetAlert>[];
    final now = DateTime.now();

    // Tính số ngày đã trôi qua và tổng số ngày trong tháng
    final daysInMonth = DateTime(currentMonth.year, currentMonth.month + 1, 0).day;
    final daysElapsed = now.day;
    final timeElapsedPercentage = (daysElapsed / daysInMonth) * 100;

    // ===== 1. KIỂM TRA NGÂN SÁCH TỔNG (Overall Budget) =====
    try {
      final overallProgress = await _dbHelper.getOverallBudgetProgress();
      log('📊 Overall Budget Progress: $overallProgress');

      if (overallProgress != null) {
        final budgetAmount = (overallProgress['budgetAmount'] as num).toDouble();
        final spent = (overallProgress['totalSpent'] as num).toDouble();

        log('💰 Ngân sách tổng: ${budgetAmount.toStringAsFixed(0)} VND');
        log('💸 Đã chi: ${spent.toStringAsFixed(0)} VND');

        if (budgetAmount > 0) {
          // Tính % đã sử dụng
          final usedPercentage = (spent / budgetAmount) * 100;

          // Tính tốc độ chi tiêu
          final expectedUsage = timeElapsedPercentage;
          final spendingRate = expectedUsage > 0 ? usedPercentage / expectedUsage : 0.0;

          // Dự đoán số tiền vượt nếu tiếp tục chi tiêu
          final projectedTotal = daysElapsed > 0 ? (spent / daysElapsed) * daysInMonth : spent;
          final projectedOverage = math.max(0.0, projectedTotal - budgetAmount);

          // Xác định mức độ nghiêm trọng (giảm ngưỡng để dễ cảnh báo hơn)
          String severity;
          if (usedPercentage >= 100) {
            severity = 'high';
          } else if (usedPercentage >= 90) {
            severity = 'high';
          } else if (spendingRate >= 1.5 && usedPercentage >= 40) {
            severity = 'high';
          } else if (spendingRate >= 1.3 && usedPercentage >= 30) {
            severity = 'medium';
          } else if (usedPercentage >= 70) {
            severity = 'medium';
          } else if (spendingRate >= 1.1) {
            severity = 'medium';
          } else if (usedPercentage >= 50) {
            severity = 'low';
          } else {
            severity = 'low'; // Luôn hiển thị để người dùng theo dõi
          }

          log('⚠️ Thêm cảnh báo ngân sách tổng: severity=$severity, used=$usedPercentage%');

          alerts.add(BudgetAlert(
            categoryName: '💰 Ngân sách tổng', // Đánh dấu đặc biệt
            usedPercentage: usedPercentage,
            daysElapsed: daysElapsed,
            timeElapsedPercentage: timeElapsedPercentage,
            spendingRate: spendingRate,
            projectedOverage: projectedOverage,
            severity: severity,
            budgetAmount: budgetAmount,
            spentAmount: spent,
          ));
        }
      } else {
        log('⚠️ Không tìm thấy ngân sách tổng đang hoạt động');
      }
    } catch (e) {
      log('❌ Lỗi kiểm tra ngân sách tổng: $e');
    }

    // ===== 2. KIỂM TRA NGÂN SÁCH THEO DANH MỤC =====
    try {
      final budgetProgress = await _dbHelper.getBudgetProgress();

      for (var item in budgetProgress) {
        final budgetAmount = (item['budgetAmount'] as num).toDouble();
        final spent = (item['totalSpent'] as num).toDouble();
        final categoryName = item['categoryName'] as String? ?? 'Tổng chi tiêu';

        if (budgetAmount <= 0) continue;

        // Tính % đã sử dụng
        final usedPercentage = (spent / budgetAmount) * 100;

        // Tính tốc độ chi tiêu
        final expectedUsage = timeElapsedPercentage;
        final spendingRate = expectedUsage > 0 ? usedPercentage / expectedUsage : 0.0;

        // Dự đoán số tiền vượt nếu tiếp tục chi tiêu
        final dailyAverage = daysElapsed > 0 ? spent / daysElapsed : 0;
        final projectedTotal = dailyAverage * daysInMonth;
        final projectedOverage = math.max(0.0, projectedTotal - budgetAmount);

        log('📋 [$categoryName] Budget: ${budgetAmount.toStringAsFixed(0)}, Spent: ${spent.toStringAsFixed(0)}');
        log('📊 Ngày đã qua: $daysElapsed/$daysInMonth ngày (${timeElapsedPercentage.toStringAsFixed(1)}%)');
        log('💸 Chi TB/ngày: ${dailyAverage.toStringAsFixed(0)} VND');
        log('🔮 Dự đoán cuối tháng: ${projectedTotal.toStringAsFixed(0)} VND');
        log('⚠️ Dự kiến vượt: ${projectedOverage.toStringAsFixed(0)} VND');

        // ===== LUÔN HIỂN THỊ TẤT CẢ NGÂN SÁCH, CHỈ PHÂN LOẠI MÀU =====
        String severity;

        // ĐỎ (high) - Nguy hiểm
        if (usedPercentage >= 100) {
          severity = 'high'; // Đã vượt ngân sách
        } else if (usedPercentage >= 90) {
          severity = 'high'; // Sắp hết (≥90%)
        } else if (spendingRate >= 1.5 && usedPercentage >= 40) {
          severity = 'high'; // Chi nhanh gấp 1.5x và đã dùng ≥40%
        }
        // CAM (medium) - Cảnh báo
        else if (usedPercentage >= 70) {
          severity = 'medium'; // Đã dùng ≥70%
        } else if (spendingRate >= 1.3) {
          severity = 'medium'; // Chi nhanh gấp 1.3x
        } else if (projectedOverage > 0) {
          severity = 'medium'; // Có dự kiến vượt
        }
        // XANH (low) - An toàn
        else {
          severity = 'low'; // Còn an toàn
        }

        log('✅ Thêm ngân sách [$categoryName]: severity=$severity, used=${usedPercentage.toStringAsFixed(1)}%');

        alerts.add(BudgetAlert(
          categoryName: categoryName,
          usedPercentage: usedPercentage,
          daysElapsed: daysElapsed,
          timeElapsedPercentage: timeElapsedPercentage,
          spendingRate: spendingRate,
          projectedOverage: projectedOverage,
          severity: severity,
          budgetAmount: budgetAmount,
          spentAmount: spent,
        ));
      }
    } catch (e) {
      log('Lỗi kiểm tra ngân sách từ bảng budgets: $e');
    }

    // ===== KIỂM TRA HẠN MỨC TỪ CATEGORIES (Backup) =====
    try {
      final categories = await _dbHelper.getAllCategories();
      final startDate = DateTime(currentMonth.year, currentMonth.month, 1);
      final endDate = DateTime(currentMonth.year, currentMonth.month + 1, 0, 23, 59, 59);

      for (var category in categories) {
        if (category.type != 'expense' || category.budget == null || category.budget! <= 0) {
          continue;
        }

        // Kiểm tra xem category này đã có trong alerts từ budgets chưa
        final existingAlert = alerts.any((alert) => alert.categoryName == category.name);
        if (existingAlert) continue; // Skip nếu đã có từ budgets

        // Lấy chi tiêu của danh mục này trong tháng
        final transactions = await _dbHelper.getTransactionsByDateRange(startDate, endDate);
        final categorySpending = transactions
            .where((t) => t.type == 'expense' && t.categoryId == category.id)
            .fold(0.0, (sum, t) => sum + t.amount);

        final budget = (category.budget! as num).toDouble();
        final usedPercentage = (categorySpending / budget) * 100;

        // Tính tốc độ chi tiêu
        final expectedUsage = timeElapsedPercentage;
        final spendingRate = expectedUsage > 0 ? usedPercentage / expectedUsage : 0.0;

        // Dự đoán số tiền vượt nếu tiếp tục chi tiêu
        final projectedTotal = daysElapsed > 0 ? (categorySpending / daysElapsed) * daysInMonth : categorySpending;
        final projectedOverage = math.max(0.0, projectedTotal - budget);

        // Tạo cảnh báo nếu vượt hoặc có nguy cơ vượt
        String? severity;
        if (usedPercentage >= 100) {
          severity = 'high';
        } else if (spendingRate >= 1.5 && usedPercentage >= 50) {
          severity = 'high';
        } else if (spendingRate >= 1.2 && usedPercentage >= 40) {
          severity = 'medium';
        } else if (spendingRate >= 1.1 && usedPercentage >= 60) {
          severity = 'medium';
        }

        if (severity != null) {
          alerts.add(BudgetAlert(
            categoryName: category.name,
            usedPercentage: usedPercentage,
            daysElapsed: daysElapsed,
            timeElapsedPercentage: timeElapsedPercentage,
            spendingRate: spendingRate,
            projectedOverage: projectedOverage,
            severity: severity,
            budgetAmount: budget,
            spentAmount: categorySpending,
          ));
        }
      }
    } catch (e) {
      log('Lỗi kiểm tra hạn mức từ categories: $e');
    }

    // Sắp xếp theo mức độ nghiêm trọng
    alerts.sort((a, b) {
      final severityOrder = {'high': 0, 'medium': 1, 'low': 2};
      return severityOrder[a.severity]!.compareTo(severityOrder[b.severity]!);
    });

    return alerts;
  }

  // ==================== GỢI Ý NGÂN SÁCH ====================

  /// Đề xuất ngân sách hợp lý cho tháng mới
  Future<List<BudgetSuggestion>> suggestBudgets({
    required DateTime currentMonth,
  }) async {
    final suggestions = <BudgetSuggestion>[];

    final categories = await _dbHelper.getAllCategories();

    for (var category in categories) {
      if (category.type != 'expense') continue;

      // Tính chi tiêu trung bình 3 tháng gần nhất
      final monthlySpending = <double>[];

      for (var i = 1; i <= 3; i++) {
        final targetMonth = DateTime(currentMonth.year, currentMonth.month - i);
        final startDate = DateTime(targetMonth.year, targetMonth.month, 1);
        final endDate = DateTime(targetMonth.year, targetMonth.month + 1, 0, 23, 59, 59);

        final transactions = await _dbHelper.getTransactionsByDateRange(startDate, endDate);
        final spending = transactions
            .where((t) => t.type == 'expense' && t.categoryId == category.id)
            .fold(0.0, (sum, t) => sum + t.amount);

        if (spending > 0) {
          monthlySpending.add(spending);
        }
      }

      if (monthlySpending.isEmpty) continue;

      // Tính trung bình và thêm buffer 10%
      final avg3Months = monthlySpending.reduce((a, b) => a + b) / monthlySpending.length;
      final suggestedBudget = (avg3Months * 1.1).roundToDouble(); // Thêm 10% buffer

      final currentBudget = category.budget ?? 0;

      String reason;
      if (currentBudget == 0) {
        reason = 'Dựa trên chi tiêu trung bình 3 tháng gần nhất';
      } else if (suggestedBudget > currentBudget * 1.2) {
        reason = 'Chi tiêu thực tế cao hơn ngân sách hiện tại';
      } else if (suggestedBudget < currentBudget * 0.8) {
        reason = 'Bạn đang chi tiêu thấp hơn ngân sách, có thể giảm';
      } else {
        reason = 'Ngân sách phù hợp với thói quen chi tiêu';
      }

      suggestions.add(BudgetSuggestion(
        categoryName: category.name,
        currentBudget: currentBudget,
        suggestedBudget: suggestedBudget,
        reason: reason,
        avg3MonthsSpending: avg3Months,
      ));
    }

    return suggestions;
  }

  // ==================== DỮ LIỆU CHO BIỂU ĐỒ ====================

  /// Lấy dữ liệu cho biểu đồ dự đoán
  Future<List<MonthlySpendingData>> getPredictionChartData({
    required DateTime currentMonth,
    int monthsToShow = 6,
  }) async {
    final chartData = <MonthlySpendingData>[];

    // Lấy dữ liệu thực tế các tháng trước
    for (var i = monthsToShow - 1; i >= 1; i--) {
      final targetMonth = DateTime(currentMonth.year, currentMonth.month - i);
      final startDate = DateTime(targetMonth.year, targetMonth.month, 1);
      final endDate = DateTime(targetMonth.year, targetMonth.month + 1, 0, 23, 59, 59);

      final transactions = await _dbHelper.getTransactionsByDateRange(startDate, endDate);
      final totalExpense = transactions
          .where((t) => t.type == 'expense')
          .fold(0.0, (sum, t) => sum + t.amount);

      chartData.add(MonthlySpendingData(
        month: targetMonth,
        actualAmount: totalExpense,
        isActual: true,
      ));
    }

    // Thêm tháng hiện tại
    final currentStartDate = DateTime(currentMonth.year, currentMonth.month, 1);
    final currentEndDate = DateTime(currentMonth.year, currentMonth.month + 1, 0, 23, 59, 59);
    final currentTransactions = await _dbHelper.getTransactionsByDateRange(currentStartDate, currentEndDate);
    final currentExpense = currentTransactions
        .where((t) => t.type == 'expense')
        .fold(0.0, (sum, t) => sum + t.amount);

    chartData.add(MonthlySpendingData(
      month: currentMonth,
      actualAmount: currentExpense,
      isActual: true,
    ));

    // Thêm dự đoán tháng sau
    final prediction = await predictNextMonthSpending(currentMonth: currentMonth);
    final nextMonth = DateTime(currentMonth.year, currentMonth.month + 1);

    chartData.add(MonthlySpendingData(
      month: nextMonth,
      actualAmount: 0,
      predictedAmount: prediction.predictedAmount,
      isActual: false,
    ));

    return chartData;
  }

  // ==================== PHÂN TÍCH THEO THỜI GIAN TRONG NGÀY ====================

  /// Phân tích chi tiêu theo thời gian trong ngày (Sáng/Trưa/Chiều/Tối)
  Future<List<TimeBasedSpending>> analyzeTimeBasedSpending({
    required DateTime currentMonth,
  }) async {
    final startDate = DateTime(currentMonth.year, currentMonth.month, 1);
    final endDate = DateTime(currentMonth.year, currentMonth.month + 1, 0, 23, 59, 59);

    final transactions = await _dbHelper.getTransactionsByDateRange(startDate, endDate);
    final expenses = transactions.where((t) => t.type == 'expense').toList();

    if (expenses.isEmpty) {
      return const [];
    }

    // Phân loại theo thời gian
    final periodSpending = <String, double>{};
    final periodCount = <String, int>{};

    for (var expense in expenses) {
      final period = _getTimePeriod(expense.date.hour);
      periodSpending[period] = (periodSpending[period] ?? 0) + expense.amount;
      periodCount[period] = (periodCount[period] ?? 0) + 1;
    }

    final totalSpending = expenses.fold(0.0, (sum, e) => sum + e.amount);

    // Tạo danh sách kết quả
    final results = <TimeBasedSpending>[];
    final periods = ['Sáng', 'Trưa', 'Chiều', 'Tối'];

    for (var period in periods) {
      final amount = periodSpending[period] ?? 0;
      final count = periodCount[period] ?? 0;
      final percentage = totalSpending > 0 ? (amount / totalSpending) * 100 : 0;

      results.add(TimeBasedSpending(
        period: period,
        amount: amount.toDouble(),
        transactionCount: count,
        percentage: percentage.toDouble(),
      ));
    }

    // Sắp xếp theo số tiền giảm dần
    results.sort((a, b) => b.amount.compareTo(a.amount));

    return results;
  }

  /// Xác định thời gian trong ngày dựa trên giờ
  String _getTimePeriod(int hour) {
    if (hour >= 5 && hour < 11) {
      return 'Sáng'; // 5h-11h
    } else if (hour >= 11 && hour < 14) {
      return 'Trưa'; // 11h-14h
    } else if (hour >= 14 && hour < 18) {
      return 'Chiều'; // 14h-18h
    } else {
      return 'Tối'; // 18h-5h
    }
  }

  // ==================== PHÂN CỤM HÀNH VI (K-MEANS) ====================

  /// Phân cụm hành vi chi tiêu bằng K-means clustering
  Future<SpendingCluster> clusterSpendingBehavior({
    required DateTime currentMonth,
  }) async {
    try {
      // Lấy dữ liệu 3 tháng gần nhất để phân tích
      final data = await _getSpendingFeatures(currentMonth: currentMonth, monthsBack: 3);

      if (data['avgMonthlySpending'] == 0) {
        return const SpendingCluster(
          clusterName: 'Chưa xác định',
          description: 'Chưa đủ dữ liệu để phân tích',
          avgMonthlySpending: 0,
          spendingToIncomeRatio: 0,
          highValueTransactionCount: 0,
        );
      }

      // Áp dụng quy tắc phân loại đơn giản (thay cho K-means phức tạp)
      // Có thể nâng cấp sau bằng ml_algo nếu cần

      final avgSpending = data['avgMonthlySpending'] as double;
      final ratio = data['spendingToIncomeRatio'] as double;
      final highValueCount = data['highValueTransactionCount'] as int;

      String clusterName;
      String description;

      // Phân loại dựa trên 3 tiêu chí
      if (ratio < 0.6 && avgSpending < 5000000) {
        // Chi ít và tỉ lệ thấp
        clusterName = 'Tiết kiệm';
        description = 'Bạn chi tiêu cẩn trọng và có kế hoạch tốt. Tỉ lệ chi/thu dưới 60%.';
      } else if (ratio >= 0.9 || avgSpending > 10000000 || highValueCount > 15) {
        // Chi nhiều hoặc tỉ lệ cao
        clusterName = 'Thoải mái';
        description = 'Bạn chi tiêu thoải mái, có nhiều giao dịch giá trị cao. Cân nhắc tiết kiệm hơn.';
      } else {
        // Trung bình
        clusterName = 'Cân đối';
        description = 'Bạn có phong cách chi tiêu cân đối, vừa phải giữa tiết kiệm và thoải mái.';
      }

      return SpendingCluster(
        clusterName: clusterName,
        description: description,
        avgMonthlySpending: avgSpending,
        spendingToIncomeRatio: ratio,
        highValueTransactionCount: highValueCount,
      );
    } catch (e) {
      log('Lỗi phân cụm hành vi: $e');
      return const SpendingCluster(
        clusterName: 'Lỗi',
        description: 'Không thể phân tích hành vi',
        avgMonthlySpending: 0,
        spendingToIncomeRatio: 0,
        highValueTransactionCount: 0,
      );
    }
  }

  /// Lấy các đặc trưng để phân cụm
  Future<Map<String, dynamic>> _getSpendingFeatures({
    required DateTime currentMonth,
    required int monthsBack,
  }) async {
    final monthlySpending = <double>[];
    final monthlyIncome = <double>[];
    var totalHighValueTx = 0;

    for (var i = 0; i < monthsBack; i++) {
      final targetMonth = DateTime(currentMonth.year, currentMonth.month - i);
      final startDate = DateTime(targetMonth.year, targetMonth.month, 1);
      final endDate = DateTime(targetMonth.year, targetMonth.month + 1, 0, 23, 59, 59);

      final transactions = await _dbHelper.getTransactionsByDateRange(startDate, endDate);

      final totalExpense = transactions
          .where((t) => t.type == 'expense')
          .fold(0.0, (sum, t) => sum + t.amount);

      final totalIncome = transactions
          .where((t) => t.type == 'income')
          .fold(0.0, (sum, t) => sum + t.amount);

      final highValue = transactions
          .where((t) => t.type == 'expense' && t.amount > 500000)
          .length;

      if (totalExpense > 0) {
        monthlySpending.add(totalExpense);
      }
      if (totalIncome > 0) {
        monthlyIncome.add(totalIncome);
      }
      totalHighValueTx += highValue;
    }

    final avgSpending = monthlySpending.isEmpty
        ? 0.0
        : monthlySpending.reduce((a, b) => a + b) / monthlySpending.length;

    final avgIncome = monthlyIncome.isEmpty
        ? 0.0
        : monthlyIncome.reduce((a, b) => a + b) / monthlyIncome.length;

    final ratio = avgIncome > 0 ? avgSpending / avgIncome : 0.0;

    return {
      'avgMonthlySpending': avgSpending,
      'avgMonthlyIncome': avgIncome,
      'spendingToIncomeRatio': ratio,
      'highValueTransactionCount': totalHighValueTx,
    };
  }

  // ==================== HELPER METHODS ====================

  String _formatMonth(DateTime date) {
    final months = ['', 'Tháng 1', 'Tháng 2', 'Tháng 3', 'Tháng 4', 'Tháng 5',
      'Tháng 6', 'Tháng 7', 'Tháng 8', 'Tháng 9', 'Tháng 10', 'Tháng 11', 'Tháng 12'];
    return '${months[date.month]}/${date.year}';
  }

  String _getDayName(int weekday) {
    final days = ['', 'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
    return days[weekday];
  }

  /// Tạo màu sắc động cho danh mục dựa trên tên
  int _generateCategoryColor(String categoryName) {
    // Danh sách màu sắc đẹp và dễ phân biệt
    final colors = [
      0xFFE53935, // Red
      0xFFD81B60, // Pink
      0xFF8E24AA, // Purple
      0xFF5E35B1, // Deep Purple
      0xFF3949AB, // Indigo
      0xFF1E88E5, // Blue
      0xFF039BE5, // Light Blue
      0xFF00ACC1, // Cyan
      0xFF00897B, // Teal
      0xFF43A047, // Green
      0xFF7CB342, // Light Green
      0xFFC0CA33, // Lime
      0xFFFDD835, // Yellow
      0xFFFFB300, // Amber
      0xFFFB8C00, // Orange
      0xFFF4511E, // Deep Orange
      0xFF6D4C41, // Brown
      0xFF757575, // Grey
      0xFF546E7A, // Blue Grey
    ];

    // Sử dụng hashCode của tên để chọn màu nhất quán
    final hash = categoryName.hashCode.abs();
    final colorIndex = hash % colors.length;

    return colors[colorIndex];
  }
}

