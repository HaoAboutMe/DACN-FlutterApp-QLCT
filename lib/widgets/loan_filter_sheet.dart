import 'package:flutter/material.dart';
import '../models/loan_filters.dart';

/// Bottom Sheet for Loan Status and Due Date Filters
/// Bộ lọc khoản vay (theo trạng thái và hạn)
class LoanFilterSheet extends StatefulWidget {
  final LoanFilters initialFilters;

  const LoanFilterSheet({
    super.key,
    required this.initialFilters,
  });

  @override
  State<LoanFilterSheet> createState() => _LoanFilterSheetState();
}

class _LoanFilterSheetState extends State<LoanFilterSheet> {
  late LoanFilters _tempFilters;

  @override
  void initState() {
    super.initState();
    _tempFilters = widget.initialFilters.copyWith();
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
                Icons.filter_list,
                color: colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Lọc khoản vay',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Status Section
          Text(
            'Trạng thái',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),

          CheckboxListTile(
            value: _tempFilters.filterActive,
            onChanged: (value) {
              setState(() {
                _tempFilters.filterActive = value ?? false;
              });
            },
            title: const Text('Đang hoạt động'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: colorScheme.primary,
          ),

          CheckboxListTile(
            value: _tempFilters.filterCompleted,
            onChanged: (value) {
              setState(() {
                _tempFilters.filterCompleted = value ?? false;
              });
            },
            title: const Text('Đã thanh toán'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: colorScheme.primary,
          ),

          const SizedBox(height: 24),

          // Due Date Section
          Text(
            'Tình trạng hạn',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),

          CheckboxListTile(
            value: _tempFilters.filterDueSoon,
            onChanged: (value) {
              setState(() {
                _tempFilters.filterDueSoon = value ?? false;
              });
            },
            title: const Text('Sắp đến hạn (≤7 ngày)'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: colorScheme.primary,
          ),

          CheckboxListTile(
            value: _tempFilters.filterOverdue,
            onChanged: (value) {
              setState(() {
                _tempFilters.filterOverdue = value ?? false;
              });
            },
            title: const Text('Đã quá hạn'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: colorScheme.primary,
          ),

          CheckboxListTile(
            value: _tempFilters.filterNoDueDate,
            onChanged: (value) {
              setState(() {
                _tempFilters.filterNoDueDate = value ?? false;
              });
            },
            title: const Text('Không có hạn'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: colorScheme.primary,
          ),

          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _tempFilters.resetLoanFilters();
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

