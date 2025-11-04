import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/loan_filters.dart';
import 'month_year_picker_dialog.dart';

/// Bottom Sheet for Loan Time Filter
/// Bộ lọc thời gian (theo thời điểm tạo khoản vay)
class LoanTimeFilterSheet extends StatefulWidget {
  final LoanFilters initialFilters;

  const LoanTimeFilterSheet({
    super.key,
    required this.initialFilters,
  });

  @override
  State<LoanTimeFilterSheet> createState() => _LoanTimeFilterSheetState();
}

class _LoanTimeFilterSheetState extends State<LoanTimeFilterSheet> {
  late LoanFilters _tempFilters;
  late bool _allTimeSelected;
  late DateTime? _selectedMonth;

  @override
  void initState() {
    super.initState();
    _tempFilters = widget.initialFilters.copyWith();
    _allTimeSelected = _tempFilters.filterAllTime;
    _selectedMonth = _tempFilters.selectedMonth ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
  }

  Future<void> _selectMonth() async {
    final pickedDate = await showMonthYearPicker(
      context: context,
      initialDate: _selectedMonth ?? DateTime.now(),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedMonth = pickedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.access_time,
                color: colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Lọc theo thời gian',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Time Filter Options
          Text(
            'Lọc theo thời gian tạo',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          // All Time Option
          InkWell(
            onTap: () {
              setState(() {
                _allTimeSelected = true;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Radio<bool>(
                    value: true,
                    groupValue: _allTimeSelected,
                    onChanged: (value) {
                      setState(() {
                        _allTimeSelected = value ?? true;
                      });
                    },
                    activeColor: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tất cả thời gian',
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Specific Month Option
          InkWell(
            onTap: () {
              setState(() {
                _allTimeSelected = false;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Radio<bool>(
                    value: false,
                    groupValue: _allTimeSelected,
                    onChanged: (value) {
                      setState(() {
                        _allTimeSelected = value ?? false;
                      });
                    },
                    activeColor: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Chọn tháng/năm cụ thể',
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Month Selector (visible only when specific month is selected)
          if (!_allTimeSelected) ...[
            const SizedBox(height: 16),
            InkWell(
              onTap: _selectMonth,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tháng được chọn',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MMMM, yyyy', 'vi_VN')
                                .format(_selectedMonth!)
                                .replaceFirst(RegExp(r'tháng '), 'Tháng '),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _allTimeSelected = true;
                      _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    side: BorderSide(color: colorScheme.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Đặt lại',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Update temp filters
                    _tempFilters.filterAllTime = _allTimeSelected;
                    _tempFilters.selectedMonth = _allTimeSelected ? null : _selectedMonth;
                    Navigator.pop(context, _tempFilters);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Áp dụng',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

