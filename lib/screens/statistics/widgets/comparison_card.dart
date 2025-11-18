import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../utils/currency_formatter.dart';
import '../providers/expense_data_provider.dart';

class ComparisonCard extends StatelessWidget {
  const ComparisonCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseDataProvider>(context);
    final savings = provider.totalIncome - provider.totalExpense;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            savings >= 0 ? Icons.trending_up : Icons.trending_down,
            color: savings >= 0 ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              savings >= 0
                  ? 'Tiết kiệm được ${CurrencyFormatter.formatAmount(savings.abs())} trong tháng này'
                  : 'Chi vượt ${CurrencyFormatter.formatAmount(savings.abs())} so với thu nhập',
              style: TextStyle(
                color: savings >= 0 ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

