import 'package:flutter/material.dart';
import '../../../models/transaction.dart' as transaction_model;
import '../../../models/category.dart';
import '../home_colors.dart';
import 'transaction_item.dart';
import 'empty_state.dart';

class RecentTransactions extends StatelessWidget {
  final List<transaction_model.Transaction> transactions;
  final Map<int, Category> categoriesMap;

  const RecentTransactions({
    super.key,
    required this.transactions,
    required this.categoriesMap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HomeColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: HomeColors.cardShadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Giao dịch gần đây',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: HomeColors.textPrimary,
            ),
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
      separatorBuilder: (context, index) => const Divider(height: 24),
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
