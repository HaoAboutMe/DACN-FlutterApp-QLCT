import 'package:flutter/material.dart';
import '../../../models/transaction.dart' as transaction_model;
import '../../../models/category.dart';
import 'transaction_item.dart';
import 'empty_state.dart';

class RecentTransactions extends StatelessWidget {
  final List<transaction_model.Transaction> transactions;
  final Map<int, Category> categoriesMap;
  final VoidCallback? onViewAllPressed;

  const RecentTransactions({
    super.key,
    required this.transactions,
    required this.categoriesMap,
    this.onViewAllPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
              ? Colors.black.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.08),
            blurRadius: isDark ? 8 : 10,
            offset: Offset(0, isDark ? 3 : 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Giao dịch gần đây',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (onViewAllPressed != null)
                GestureDetector(
                  onTap: onViewAllPressed,
                  child: Row(
                    children: [
                      Text(
                        'Tất cả',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Theme.of(context).colorScheme.primary,
                        size: 16,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          transactions.isEmpty
              ? const EmptyState()
              : _buildTransactionsList(),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      separatorBuilder: (context, index) => Divider(
        height: 24,
        color: Theme.of(context).dividerColor,
      ),
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        final category = transaction.categoryId != null
            ? categoriesMap[transaction.categoryId!]
            : null;

        return TransactionItem(
          transaction: transaction,
          category: category,
        );
      },
    );
  }
}