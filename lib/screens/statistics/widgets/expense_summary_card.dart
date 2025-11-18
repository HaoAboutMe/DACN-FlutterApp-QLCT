import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../utils/currency_formatter.dart';
import '../providers/expense_data_provider.dart';

class ExpenseSummaryCard extends StatelessWidget {
  const ExpenseSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseDataProvider>(
      builder: (context, provider, child) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => provider.toggleExpenseIncome(true), // Chọn chi tiêu
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: provider.isShowingExpense
                            ? const Color(0xFFF44336) // Màu đỏ cho chi tiêu
                            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                        width: provider.isShowingExpense ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: provider.isShowingExpense
                              ? const Color(0xFFF44336).withValues(alpha: 0.1)
                              : Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.trending_down,
                                color: provider.isShowingExpense
                                    ? const Color(0xFFF44336)
                                    : Theme.of(context).colorScheme.outline,
                                size: 16),
                            const SizedBox(width: 4),
                            Text('Chi tiêu',
                                style: TextStyle(
                                  color: provider.isShowingExpense
                                      ? const Color(0xFFF44336)
                                      : Theme.of(context).colorScheme.outline,
                                  fontWeight: provider.isShowingExpense ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 14,
                                )),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          provider.isMoneyVisible
                              ? CurrencyFormatter.formatAmount(provider.totalExpense)
                              : '••••••••',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: provider.isShowingExpense
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => provider.toggleExpenseIncome(false), // Chọn thu nhập
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: !provider.isShowingExpense
                            ? const Color(0xFF4CAF50) // Màu xanh cho thu nhập
                            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                        width: !provider.isShowingExpense ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: !provider.isShowingExpense
                              ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                              : Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.trending_up,
                                color: !provider.isShowingExpense
                                    ? const Color(0xFF4CAF50)
                                    : Theme.of(context).colorScheme.outline,
                                size: 16),
                            const SizedBox(width: 4),
                            Text('Thu nhập',
                                style: TextStyle(
                                  color: !provider.isShowingExpense
                                      ? const Color(0xFF4CAF50)
                                      : Theme.of(context).colorScheme.outline,
                                  fontWeight: !provider.isShowingExpense ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 14,
                                )),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          provider.isMoneyVisible
                              ? CurrencyFormatter.formatAmount(provider.totalIncome)
                              : '••••••••',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: !provider.isShowingExpense
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

