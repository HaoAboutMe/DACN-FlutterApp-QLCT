import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../utils/currency_formatter.dart';
import '../models/expense_category.dart';
import '../providers/expense_data_provider.dart';

class CategoryItem extends StatelessWidget {
  final ExpenseCategory category;
  final bool isHighlighted;
  final VoidCallback? onTap;

  const CategoryItem({
    super.key,
    required this.category,
    required this.isHighlighted,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseDataProvider>(
      builder: (context, provider, child) {
        return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isHighlighted
                  ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                  : Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    category.icon,
                    color: category.color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '${category.percentage.toStringAsFixed(1)}% của tổng ${provider.isShowingExpense ? "chi tiêu" : "thu nhập"}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      provider.isMoneyVisible
                          ? CurrencyFormatter.formatAmount(category.amount)
                          : '••••••••',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isHighlighted ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Container(
                      width: 60,
                      height: 4,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: category.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

