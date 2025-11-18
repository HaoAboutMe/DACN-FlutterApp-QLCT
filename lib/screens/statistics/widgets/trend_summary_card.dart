import 'package:flutter/material.dart';
import '../../../utils/currency_formatter.dart';
import '../providers/expense_data_provider.dart';
import 'trend_info_card.dart';

class TrendSummaryCard extends StatelessWidget {
  final ExpenseDataProvider provider;

  const TrendSummaryCard({
    super.key,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    // Lấy tháng hiện tại và tháng trước từ provider
    final currentMonth = provider.selectedMonth;
    final previousMonth = DateTime(currentMonth.year, currentMonth.month - 1);

    // Lấy dữ liệu từ dailyExpenses
    final previousMonthAmount = provider.dailyExpenses.isNotEmpty
        ? provider.dailyExpenses[0].amount * 1000000
        : 0.0;

    final currentMonthAmount = provider.dailyExpenses.length >= 2
        ? provider.dailyExpenses[1].amount * 1000000
        : 0.0;

    // Tính chênh lệch giữa 2 tháng
    final difference = currentMonthAmount - previousMonthAmount;

    // Tính phần trăm thay đổi
    final percentageChange = previousMonthAmount > 0
        ? ((currentMonthAmount - previousMonthAmount) / previousMonthAmount * 100)
        : (currentMonthAmount > 0 ? 100.0 : 0.0);

    final isIncrease = difference > 0;
    final isDecrease = difference < 0;

    return Column(
      children: [
        // Tiêu đề
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.trending_up,
                color: provider.isShowingExpense
                    ? Theme.of(context).colorScheme.primary
                    : const Color(0xFF4CAF50),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Tổng quan xu hướng',
                style: TextStyle(
                  color: provider.isShowingExpense
                      ? Theme.of(context).colorScheme.primary
                      : const Color(0xFF4CAF50),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),

        // Grid các thông tin so sánh 2 tháng
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              // Hàng 1: Tháng trước (trái) và Tháng hiện tại (phải)
              Row(
                children: [
                  Expanded(
                    child: TrendInfoCard(
                      icon: Icons.history,
                      iconColor: Theme.of(context).colorScheme.secondary,
                      title: 'Tháng ${previousMonth.month}/${previousMonth.year}',
                      value: CurrencyFormatter.formatAmount(previousMonthAmount),
                      subtitle: 'Tháng trước',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TrendInfoCard(
                      icon: Icons.calendar_month,
                      iconColor: Theme.of(context).colorScheme.primary,
                      title: 'Tháng ${currentMonth.month}/${currentMonth.year}',
                      value: CurrencyFormatter.formatAmount(currentMonthAmount),
                      subtitle: 'Tháng hiện tại',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Hàng 2: Chênh lệch và Phần trăm thay đổi
              Row(
                children: [
                  Expanded(
                    child: TrendInfoCard(
                      icon: isIncrease
                          ? Icons.arrow_upward
                          : isDecrease
                          ? Icons.arrow_downward
                          : Icons.remove,
                      iconColor: isIncrease
                          ? Theme.of(context).colorScheme.error
                          : isDecrease
                          ? const Color(0xFF4CAF50)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      title: 'Chênh lệch',
                      value: CurrencyFormatter.formatAmount(difference.abs()),
                      subtitle: isIncrease
                          ? 'Tăng'
                          : isDecrease
                          ? 'Giảm'
                          : 'Không đổi',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TrendInfoCard(
                      icon: Icons.percent,
                      iconColor: isIncrease
                          ? Theme.of(context).colorScheme.error
                          : isDecrease
                          ? const Color(0xFF4CAF50)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      title: 'Thay đổi',
                      value: percentageChange == 0
                          ? '0%'
                          : '${percentageChange > 0 ? '+' : ''}${percentageChange.toStringAsFixed(1)}%',
                      subtitle: isIncrease
                          ? 'So với tháng trước'
                          : isDecrease
                          ? 'So với tháng trước'
                          : 'Ổn định',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

