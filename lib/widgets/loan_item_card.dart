// Task: Build a Flutter Loan Management screen
// Widget: LoanItemCard hiển thị thông tin khoản vay/đi vay
import 'package:flutter/material.dart';
import '../models/loan.dart';
import '../utils/currency_formatter.dart';

class LoanItemCard extends StatelessWidget {
  final Loan loan;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<bool?>? onSelectChanged;

  const LoanItemCard({
    Key? key,
    required this.loan,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
    this.onSelectChanged,
  }) : super(key: key);

  Color getTypeColor() {
    return loan.loanType == 'lend' ? const Color(0xFF00CEC9) : const Color(0xFF74B9FF); // Ocean theme colors
  }

  IconData getTypeIcon() {
    return loan.loanType == 'lend' ? Icons.arrow_upward : Icons.arrow_downward;
  }

  String getStatusText() {
    final now = DateTime.now();
    if (loan.dueDate == null) return 'Không xác định';
    if (loan.status == 'overdue' || (loan.dueDate!.isBefore(now))) return 'Quá hạn';
    if (loan.dueDate!.difference(now).inDays <= 7) return 'Sắp hết hạn';
    return 'Còn hạn';
  }

  Color getStatusColor() {
    final status = getStatusText();
    if (status == 'Quá hạn') return Colors.red;
    if (status == 'Sắp hết hạn') return Colors.orange;
    return Colors.green;
  }

  String getBadgeText() {
    return loan.isOldDebt == 0 ? 'MỚI' : 'CŨ';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              if (onSelectChanged != null && isSelected)
                Checkbox(
                  value: isSelected,
                  onChanged: onSelectChanged,
                ),
              Icon(getTypeIcon(), color: getTypeColor(), size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            loan.personName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: loan.isOldDebt == 0 ? const Color(0xFF00A8CC).withOpacity(0.1) : Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            getBadgeText(),
                            style: TextStyle(
                              fontSize: 12,
                              color: loan.isOldDebt == 0 ? const Color(0xFF00A8CC) : Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            )
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(CurrencyFormatter.formatVND(loan.amount),
                         style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Bắt đầu: ${loan.loanDate.day}/${loan.loanDate.month}/${loan.loanDate.year}',
                               style: const TextStyle(fontSize: 12)),
                        ),
                        if (loan.dueDate != null)
                          Expanded(
                            child: Text('Hết hạn: ${loan.dueDate!.day}/${loan.dueDate!.month}/${loan.dueDate!.year}',
                                 style: const TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(getStatusText(), style: TextStyle(color: getStatusColor(), fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
