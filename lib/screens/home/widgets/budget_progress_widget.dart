import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Widget hiển thị tiến độ ngân sách tổng trên HomePage
class BudgetProgressWidget extends StatelessWidget {
  final double budgetAmount;
  final double totalSpent;
  final double progressPercentage;
  final bool isOverBudget;
  final VoidCallback? onTap;

  const BudgetProgressWidget({
    super.key,
    required this.budgetAmount,
    required this.totalSpent,
    required this.progressPercentage,
    required this.isOverBudget,
    this.onTap,
  });

  /// Lấy màu sắc progress bar dựa trên phần trăm
  Color _getProgressColor(bool isDark) {
    if (progressPercentage >= 100) {
      return Colors.red; // Đỏ: vượt hạn mức
    } else if (progressPercentage >= 80) {
      return Colors.orange; // Cam: 80-100%
    } else {
      return isDark ? Colors.greenAccent : Colors.green; // Xanh: < 80%
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    final progressColor = _getProgressColor(isDark);
    final remainingAmount = budgetAmount - totalSpent;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: progressColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hạn mức chi tiêu tháng này',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  if (isOverBudget)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Vượt mức',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  tween: Tween<double>(
                    begin: 0,
                    end: progressPercentage.clamp(0, 100) / 100,
                  ),
                  builder: (context, value, _) {
                    return LinearProgressIndicator(
                      value: value,
                      minHeight: 12,
                      backgroundColor: isDark
                          ? Colors.grey[800]
                          : Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Progress Info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đã dùng',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currencyFormat.format(totalSpent),
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: progressColor,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: progressColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${progressPercentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: progressColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          isOverBudget ? 'Vượt' : 'Còn lại',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currencyFormat.format(remainingAmount.abs()),
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isOverBudget ? Colors.red : Colors.grey[700],
                              ),
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Budget limit
              const SizedBox(height: 8),
              Divider(color: Colors.grey[300], height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hạn mức',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  Text(
                    currencyFormat.format(budgetAmount),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

