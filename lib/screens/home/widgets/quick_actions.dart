import 'package:flutter/material.dart';
import '../home_colors.dart';
import '../home_icons.dart';

class QuickActions extends StatelessWidget {
  final VoidCallback onIncomePressed;
  final VoidCallback onExpensePressed;
  final VoidCallback onLoanGivenPressed;
  final VoidCallback onLoanReceivedPressed;

  const QuickActions({
    super.key,
    required this.onIncomePressed,
    required this.onExpensePressed,
    required this.onLoanGivenPressed,
    required this.onLoanReceivedPressed,
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
            'Thao tác nhanh',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: HomeColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: QuickActionCard(
                  icon: HomeIcons.income,
                  title: 'Thu nhập',
                  color: HomeColors.income,
                  onTap: onIncomePressed,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: QuickActionCard(
                  icon: HomeIcons.expense,
                  title: 'Chi tiêu',
                  color: HomeColors.expense,
                  onTap: onExpensePressed,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: QuickActionCard(
                  icon: HomeIcons.loanGiven,
                  title: 'Cho vay',
                  color: HomeColors.loanGiven,
                  onTap: onLoanGivenPressed,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: QuickActionCard(
                  icon: HomeIcons.loanReceived,
                  title: 'Đi vay',
                  color: HomeColors.loanReceived,
                  onTap: onLoanReceivedPressed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const QuickActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: color,
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: HomeColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
