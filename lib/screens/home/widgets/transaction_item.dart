import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/transaction.dart' as transaction_model;
import '../../../models/category.dart';
import '../../../utils/currency_formatter.dart';
import '../home_colors.dart';
import '../home_icons.dart';

class TransactionItem extends StatelessWidget {
  final transaction_model.Transaction transaction;
  final Category? category;

  const TransactionItem({
    super.key,
    required this.transaction,
    this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          _buildTransactionIcon(),
          const SizedBox(width: 16),
          _buildTransactionInfo(context),
          _buildTransactionAmount(),
        ],
      ),
    );
  }

  Widget _buildTransactionIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: HomeColors.getTransactionIconBackground(_getTransactionColor()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        _getTransactionIcon(),
        color: _getTransactionColor(),
        size: 24,
      ),
    );
  }

  Widget _buildTransactionInfo(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category?.name ?? _getTransactionTypeDisplayName(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            transaction.description,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            DateFormat('dd/MM/yyyy HH:mm').format(transaction.date),
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionAmount() {
    return Text(
      CurrencyFormatter.formatWithSign(transaction.amount, transaction.type),
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: _getTransactionColor(),
      ),
    );
  }

  IconData _getTransactionIcon() {
    if (category != null) {
      return HomeIcons.getIconFromString(category!.icon);
    }
    return HomeIcons.getTransactionTypeIcon(transaction.type);
  }

  Color _getTransactionColor() {
    switch (transaction.type) {
      case 'income':
      case 'debt_collected':
      case 'loan_received':
        return HomeColors.income;
      case 'expense':
      case 'loan_given':
      case 'debt_paid':
        return HomeColors.expense;
      default:
        return HomeColors.textSecondary;
    }
  }

  String _getTransactionTypeDisplayName() {
    switch (transaction.type) {
      case 'income':
        return 'Thu nhập';
      case 'expense':
        return 'Chi tiêu';
      case 'loan_given':
        return 'Cho vay';
      case 'loan_received':
        return 'Đi vay';
      case 'debt_paid':
        return 'Trả nợ';
      case 'debt_collected':
        return 'Thu nợ';
      default:
        return 'Giao dịch';
    }
  }
}
