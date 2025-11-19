import 'package:flutter/material.dart';
import '../../../models/loan.dart';
import '../../../utils/currency_formatter.dart';
import '../../home/home_colors.dart';

/// Widget hiển thị từng loan card trong danh sách
class LoanCardWidget extends StatelessWidget {
  final Loan loan;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMarkAsPaid;
  final VoidCallback onEdit;

  const LoanCardWidget({
    super.key,
    required this.loan,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onMarkAsPaid,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final loanColor = _getLoanColor();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerColor = isDark
        ? Theme.of(context).colorScheme.surface
        : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        borderRadius: BorderRadius.circular(12),
        color: isSelected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
            : containerColor,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? null : containerColor,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                  : null,
              boxShadow: !isSelected
                  ? [
                      BoxShadow(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // Selection checkbox or icon with badge
                if (isSelectionMode)
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    child: Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: isSelected
                          ? HomeColors.primary
                          : Colors.grey,
                      size: 24,
                    ),
                  )
                else
                  _buildIconWithBadge(isDark, loanColor),

                // Loan details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loan.personName,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getLoanTypeText(),
                        style: TextStyle(
                          fontSize: 12,
                          color: loanColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 12,
                            color: HomeColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${loan.loanDate.day}/${loan.loanDate.month}/${loan.loanDate.year}',
                            style: TextStyle(
                              fontSize: 12,
                              color: HomeColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor().withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _getStatusText(),
                              style: TextStyle(
                                fontSize: 10,
                                color: _getStatusColor(),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Amount and Edit button
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.formatAmount(loan.amount),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: loanColor,
                      ),
                    ),
                    if (loan.dueDate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Hạn: ${loan.dueDate!.day}/${loan.dueDate!.month}',
                        style: TextStyle(
                          fontSize: 11,
                          color: HomeColors.textSecondary,
                        ),
                      ),
                    ],
                    if (!isSelectionMode) ...[
                      const SizedBox(height: 8),
                      // Mark as Paid button (only show if not paid)
                      if (loan.status != 'completed' && loan.status != 'paid')
                        InkWell(
                          onTap: onMarkAsPaid,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: HomeColors.income.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 14,
                                  color: HomeColors.income,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  loan.loanType == 'lend' ? 'Thu nợ' : 'Trả nợ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: HomeColors.income,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (loan.status != 'completed' && loan.status != 'paid')
                        const SizedBox(height: 4),
                      // Edit button
                      InkWell(
                        onTap: onEdit,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: HomeColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit,
                                size: 14,
                                color: HomeColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Sửa',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: HomeColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconWithBadge(bool isDark, Color loanColor) {
    return Container(
      width: 48,
      height: 48,
      margin: const EdgeInsets.only(right: 12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Icon container
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: loanColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getLoanIcon(),
              color: loanColor,
              size: 24,
            ),
          ),
          // Badge "Cũ/Mới" căn giữa phía trên icon
          Positioned(
            top: -8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: loan.isOldDebt == 0
                      ? HomeColors.primary.withValues(alpha: 0.95)
                      : Colors.grey.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  _getBadgeText(),
                  style: TextStyle(
                    fontSize: 9,
                    color: loan.isOldDebt == 0
                        ? Colors.white
                        : (isDark ? Colors.grey[300] : Colors.grey[800]),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getLoanIcon() {
    return loan.loanType == 'lend'
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;
  }

  Color _getLoanColor() {
    return loan.loanType == 'lend'
        ? HomeColors.loanGiven
        : HomeColors.loanReceived;
  }

  String _getLoanTypeText() {
    return loan.loanType == 'lend' ? 'Cho vay' : 'Đi vay';
  }

  String _getStatusText() {
    // Kiểm tra trạng thái thanh toán trước
    if (loan.status == 'completed' || loan.status == 'paid') {
      return 'Đã thanh toán';
    }

    final now = DateTime.now();
    if (loan.dueDate == null) return 'Đang hoạt động';
    if (loan.dueDate!.isBefore(now)) return 'Quá hạn';
    if (loan.dueDate!.difference(now).inDays <= 7) return 'Sắp hết hạn';
    return 'Đang hoạt động';
  }

  Color _getStatusColor() {
    final status = _getStatusText();
    if (status == 'Quá hạn') return Colors.red;
    if (status == 'Sắp hết hạn') return Colors.orange;
    if (status == 'Đã thanh toán') return HomeColors.income;
    return HomeColors.income;
  }

  String _getBadgeText() {
    return loan.isOldDebt == 0 ? 'MỚI' : 'CŨ';
  }
}

