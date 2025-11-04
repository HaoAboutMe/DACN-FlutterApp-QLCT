import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/loan_filters.dart';

/// Widget to display active filter chips
/// Hiển thị các chip tóm tắt bộ lọc đang áp dụng
class FilterChipsWidget extends StatelessWidget {
  final LoanFilters filters;
  final Function(String) onRemoveFilter;

  const FilterChipsWidget({
    super.key,
    required this.filters,
    required this.onRemoveFilter,
  });

  List<Widget> _buildChips(BuildContext context) {
    final List<Widget> chips = [];
    final colorScheme = Theme.of(context).colorScheme;

    // Status filters
    if (filters.filterActive) {
      chips.add(_buildChip(
        context,
        label: 'Đang hoạt động',
        onDelete: () => onRemoveFilter('active'),
        color: colorScheme.primary,
      ));
    }

    if (filters.filterCompleted) {
      chips.add(_buildChip(
        context,
        label: 'Đã thanh toán',
        onDelete: () => onRemoveFilter('completed'),
        color: colorScheme.tertiary,
      ));
    }

    // Due date filters
    if (filters.filterDueSoon) {
      chips.add(_buildChip(
        context,
        label: 'Sắp đến hạn',
        onDelete: () => onRemoveFilter('due_soon'),
        color: Colors.orange,
      ));
    }

    if (filters.filterOverdue) {
      chips.add(_buildChip(
        context,
        label: 'Đã quá hạn',
        onDelete: () => onRemoveFilter('overdue'),
        color: Colors.red,
      ));
    }

    if (filters.filterNoDueDate) {
      chips.add(_buildChip(
        context,
        label: 'Không có hạn',
        onDelete: () => onRemoveFilter('no_due'),
        color: Colors.grey,
      ));
    }

    // Time filter
    if (filters.hasTimeFilter && filters.selectedMonth != null) {
      final monthText = DateFormat('MMMM, yyyy', 'vi_VN')
          .format(filters.selectedMonth!)
          .replaceFirst(RegExp(r'tháng '), 'Tháng ');

      chips.add(_buildChip(
        context,
        label: monthText,
        onDelete: () => onRemoveFilter('time'),
        color: colorScheme.secondary,
      ));
    }

    return chips;
  }

  Widget _buildChip(
    BuildContext context, {
    required String label,
    required VoidCallback onDelete,
    required Color color,
  }) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      deleteIcon: const Icon(
        Icons.close,
        size: 18,
        color: Colors.white,
      ),
      onDeleted: onDelete,
      backgroundColor: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!filters.hasAnyFilter) {
      return const SizedBox.shrink();
    }

    final chips = _buildChips(context);

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: chips,
      ),
    );
  }
}

