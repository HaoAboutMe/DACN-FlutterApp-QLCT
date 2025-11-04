import 'package:flutter/material.dart';

/// Custom Month and Year Picker Dialog
/// Shows a dialog with month and year selection
class MonthYearPickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime? minDate;
  final DateTime? maxDate;

  const MonthYearPickerDialog({
    super.key,
    required this.initialDate,
    this.minDate,
    this.maxDate,
  });

  @override
  State<MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<MonthYearPickerDialog> {
  late int _selectedYear;
  late int _selectedMonth;

  final List<String> _monthNames = [
    'Tháng 1',
    'Tháng 2',
    'Tháng 3',
    'Tháng 4',
    'Tháng 5',
    'Tháng 6',
    'Tháng 7',
    'Tháng 8',
    'Tháng 9',
    'Tháng 10',
    'Tháng 11',
    'Tháng 12',
  ];

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialDate.year;
    _selectedMonth = widget.initialDate.month;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Text(
              'Chọn Tháng và Năm',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),

            // Year Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedYear--;
                    });
                  },
                  icon: Icon(
                    Icons.chevron_left,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '$_selectedYear',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedYear++;
                    });
                  },
                  icon: Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Month Grid
            SizedBox(
              width: 300,
              height: 240,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  final month = index + 1;
                  final isSelected = _selectedMonth == month;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedMonth = month;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : (isDark
                                ? Theme.of(context).colorScheme.surfaceContainerHighest
                                : Theme.of(context).colorScheme.surfaceContainerHighest),
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? null
                            : Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withValues(alpha: 0.3),
                              ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _monthNames[index],
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Hủy',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final selectedDate = DateTime(_selectedYear, _selectedMonth, 1);
                    Navigator.pop(context, selectedDate);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text(
                    'Xác nhận',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Show the month year picker dialog
Future<DateTime?> showMonthYearPicker({
  required BuildContext context,
  required DateTime initialDate,
  DateTime? minDate,
  DateTime? maxDate,
}) async {
  return await showDialog<DateTime>(
    context: context,
    builder: (context) => MonthYearPickerDialog(
      initialDate: initialDate,
      minDate: minDate,
      maxDate: maxDate,
    ),
  );
}

