/// Model chứa kết quả dự đoán chi tiêu từ Machine Learning
class SpendingPrediction {
  /// Tháng được dự đoán (ví dụ: "Tháng 11/2025")
  final String month;

  /// Số tiền dự đoán sẽ chi
  final double predictedAmount;

  /// Độ tin cậy của dự đoán (0.0 - 1.0)
  final double confidence;

  /// Xu hướng: "increasing", "decreasing", "stable"
  final String trend;

  /// Tốc độ thay đổi (% so với tháng trước)
  final double changeRate;

  const SpendingPrediction({
    required this.month,
    required this.predictedAmount,
    required this.confidence,
    required this.trend,
    required this.changeRate,
  });

  Map<String, dynamic> toMap() {
    return {
      'month': month,
      'predictedAmount': predictedAmount,
      'confidence': confidence,
      'trend': trend,
      'changeRate': changeRate,
    };
  }

  factory SpendingPrediction.fromMap(Map<String, dynamic> map) {
    return SpendingPrediction(
      month: map['month'] as String,
      predictedAmount: (map['predictedAmount'] as num).toDouble(),
      confidence: (map['confidence'] as num).toDouble(),
      trend: map['trend'] as String,
      changeRate: (map['changeRate'] as num).toDouble(),
    );
  }
}

/// Model chứa phân tích thói quen chi tiêu
class SpendingHabit {
  /// Danh sách ngày trong tuần chi tiêu nhiều (có thể nhiều ngày nếu gần bằng nhau)
  final List<String> topSpendingDays;

  /// Danh sách danh mục chi tiêu hàng đầu (top 2-3)
  final List<TopCategoryInfo> topCategories;

  /// Thời gian trong ngày thường chi tiêu (morning/afternoon/evening/night)
  final String preferredTime;

  /// Chi tiêu trung bình hàng ngày
  final double avgDailySpending;

  /// Loại hành vi: "Tiết kiệm", "Cân đối", "Thoải mái"
  final String spendingStyle;

  const SpendingHabit({
    required this.topSpendingDays,
    required this.topCategories,
    required this.preferredTime,
    required this.avgDailySpending,
    required this.spendingStyle,
  });
}

/// Model chứa thông tin danh mục chi tiêu hàng đầu
class TopCategoryInfo {
  /// Tên danh mục
  final String name;

  /// Icon của danh mục (string để dùng với IconHelper)
  final String icon;

  /// Màu sắc của danh mục
  final int color;

  /// Tỷ lệ % chi tiêu
  final double percentage;

  /// Số tiền chi tiêu
  final double amount;

  const TopCategoryInfo({
    required this.name,
    required this.icon,
    required this.color,
    required this.percentage,
    required this.amount,
  });
}

/// Model chứa cảnh báo vượt ngân sách
class BudgetAlert {
  /// Danh mục đang có nguy cơ vượt
  final String categoryName;

  /// % ngân sách đã sử dụng
  final double usedPercentage;

  /// Số ngày đã trôi qua trong tháng
  final int daysElapsed;

  /// % thời gian đã trôi qua trong tháng
  final double timeElapsedPercentage;

  /// Tốc độ chi tiêu (so với dự kiến)
  final double spendingRate;

  /// Số tiền dự kiến vượt (nếu tiếp tục)
  final double projectedOverage;

  /// Mức độ nghiêm trọng: "low", "medium", "high"
  final String severity;

  /// Tổng ngân sách
  final double budgetAmount;

  /// Số tiền đã chi
  final double spentAmount;

  const BudgetAlert({
    required this.categoryName,
    required this.usedPercentage,
    required this.daysElapsed,
    required this.timeElapsedPercentage,
    required this.spendingRate,
    required this.projectedOverage,
    required this.severity,
    required this.budgetAmount,
    required this.spentAmount,
  });
}

/// Model cho gợi ý ngân sách
class BudgetSuggestion {
  /// Danh mục
  final String categoryName;

  /// Ngân sách hiện tại
  final double currentBudget;

  /// Ngân sách được đề xuất
  final double suggestedBudget;

  /// Lý do đề xuất
  final String reason;

  /// Chi tiêu trung bình 3 tháng gần nhất
  final double avg3MonthsSpending;

  const BudgetSuggestion({
    required this.categoryName,
    required this.currentBudget,
    required this.suggestedBudget,
    required this.reason,
    required this.avg3MonthsSpending,
  });
}

/// Model cho dữ liệu biểu đồ dự đoán
class MonthlySpendingData {
  final DateTime month;
  final double actualAmount;
  final double? predictedAmount;
  final bool isActual; // true nếu là dữ liệu thực, false nếu là dự đoán

  const MonthlySpendingData({
    required this.month,
    required this.actualAmount,
    this.predictedAmount,
    required this.isActual,
  });
}

/// Model cho phân tích thời gian chi tiêu trong ngày
class TimeBasedSpending {
  final String period; // "Sáng", "Trưa", "Chiều", "Tối"
  final double amount;
  final int transactionCount;
  final double percentage; // % so với tổng chi tiêu

  const TimeBasedSpending({
    required this.period,
    required this.amount,
    required this.transactionCount,
    required this.percentage,
  });
}

/// Model cho phân cụm hành vi chi tiêu (K-means result)
class SpendingCluster {
  final String clusterName; // "Tiết kiệm", "Cân đối", "Thoải mái"
  final String description;
  final double avgMonthlySpending;
  final double spendingToIncomeRatio;
  final int highValueTransactionCount; // Số giao dịch > 500k

  const SpendingCluster({
    required this.clusterName,
    required this.description,
    required this.avgMonthlySpending,
    required this.spendingToIncomeRatio,
    required this.highValueTransactionCount,
  });
}

