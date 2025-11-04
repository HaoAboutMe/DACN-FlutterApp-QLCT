import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'month_year_picker_dialog.dart';

/// Monthly Navigation Bar Widget
/// A reusable widget that displays a monthly navigation bar with:
/// - Previous month button (◀)
/// - Current month/year display (tappable to open picker)
/// - Next month button (▶)
class MonthlyNavigationBar extends StatelessWidget {
  final DateTime selectedMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final Function(DateTime) onMonthChanged;

  const MonthlyNavigationBar({
    super.key,
    required this.selectedMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onMonthChanged,
  });

  Future<void> _onSelectMonthYear(BuildContext context) async {
    final pickedDate = await showMonthYearPicker(
      context: context,
      initialDate: selectedMonth,
    );

    if (pickedDate != null) {
      onMonthChanged(pickedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous Month Button
          InkWell(
            onTap: onPreviousMonth,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.chevron_left,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
            ),
          ),

          // Month Year Display - Tappable
          Expanded(
            child: InkWell(
              onTap: () => _onSelectMonthYear(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Text(
                  DateFormat('MMMM, yyyy', 'vi_VN').format(selectedMonth)
                      .replaceFirst(RegExp(r'tháng '), 'Tháng '),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),

          // Next Month Button
          InkWell(
            onTap: onNextMonth,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

