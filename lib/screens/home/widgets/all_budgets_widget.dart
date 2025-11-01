import 'package:app_qlct/config/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../budget/budget_list_screen.dart';
import '../../budget/budget_category_transaction_screen.dart';

/// Widget hiển thị tất cả ngân sách đang hoạt động trên HomePage
class AllBudgetsWidget extends StatelessWidget {
  final Map<String, dynamic>? overallBudget;
  final List<Map<String, dynamic>> categoryBudgets;
  final VoidCallback onRefresh;

  const AllBudgetsWidget({
    super.key,
    this.overallBudget,
    required this.categoryBudgets,
    required this.onRefresh,
  });

  Color _getProgressColor(double percentage) {
    if (percentage >= 100) return Colors.red;
    if (percentage >= 80) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    // Nếu không có ngân sách nào, không hiển thị gì
    if (overallBudget == null && categoryBudgets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header với nút "Xem tất cả"
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Hạn mức chi tiêu',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BudgetListScreen(),
                      ),
                    ).then((_) => onRefresh());
                  },
                  child: const Text('Xem tất cả'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Ngân sách tổng (nếu có)
            if (overallBudget != null) ...[
              _buildOverallBudgetCard(overallBudget!, currencyFormat, isDark, context),
              if (categoryBudgets.isNotEmpty) const SizedBox(height: 12),
            ],

            // Ngân sách theo danh mục (tối đa 3)
            ...categoryBudgets.take(3).map((budget) {
              final isLast = categoryBudgets.indexOf(budget) == categoryBudgets.take(3).length - 1;
              return Column(
                children: [
                  _buildCategoryBudgetCard(budget, currencyFormat, isDark, context),
                  if (!isLast) const SizedBox(height: 12),
                ],
              );
            }),

            // Nút "Xem thêm" nếu có nhiều hơn 3 danh mục
            if (categoryBudgets.length > 3) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BudgetListScreen(),
                      ),
                    ).then((_) => onRefresh());
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  label: Text('Xem thêm ${categoryBudgets.length - 3} ngân sách khác'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOverallBudgetCard(
    Map<String, dynamic> data,
    NumberFormat currencyFormat,
    bool isDark,
    BuildContext context,
  ) {
    final budgetAmount = (data['budgetAmount'] as num).toDouble();
    final totalSpent = (data['totalSpent'] as num).toDouble();
    final progressPercentage = (data['progressPercentage'] as num).toDouble();
    final isOverBudget = data['isOverBudget'] as bool;
    final progressColor = _getProgressColor(progressPercentage);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: progressColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: progressColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  color: progressColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tổng ngân sách tháng này',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${currencyFormat.format(totalSpent)} / ${currencyFormat.format(budgetAmount)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              ),
              if (isOverBudget)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Vượt mức',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (progressPercentage / 100).clamp(0, 1),
              minHeight: 8,
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${progressPercentage.toStringAsFixed(1)}% đã sử dụng',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBudgetCard(
    Map<String, dynamic> data,
    NumberFormat currencyFormat,
    bool isDark,
    BuildContext context,
  ) {
    final categoryName = data['categoryName'] as String;
    final categoryIcon = data['categoryIcon'] as String;
    final budgetAmount = (data['budgetAmount'] as num).toDouble();
    final totalSpent = (data['totalSpent'] as num).toDouble();
    final progressPercentage = (data['progressPercentage'] as num).toDouble();
    final isOverBudget = data['isOverBudget'] as bool;
    final progressColor = _getProgressColor(progressPercentage);


    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceVariant : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          // Điều hướng đến màn hình chi tiết giao dịch
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BudgetCategoryTransactionScreen(
                categoryId: data['categoryId'] as int,
                categoryName: categoryName,
                categoryIcon: categoryIcon,
                startDate: DateTime.parse(data['startDate'] as String),
                endDate: DateTime.parse(data['endDate'] as String),
                budgetAmount: budgetAmount,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Builder(
                    builder: (context) {
                      final iconCode = int.tryParse(categoryIcon);
                      return iconCode != null
                          ? Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: progressColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                IconData(iconCode, fontFamily: 'MaterialIcons'),
                                color: progressColor,
                                size: 24,
                              ),
                            )
                          : Text(
                              categoryIcon,
                              style: const TextStyle(fontSize: 28),
                            );
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          categoryName,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${currencyFormat.format(totalSpent)} / ${currencyFormat.format(budgetAmount)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${progressPercentage.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: progressColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (progressPercentage / 100).clamp(0, 1),
                  minHeight: 6,
                  backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
              if (isOverBudget) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Đã vượt hạn mức',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

