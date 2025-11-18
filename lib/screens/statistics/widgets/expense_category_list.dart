import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../utils/currency_formatter.dart';
import '../models/expense_category.dart';
import '../providers/expense_data_provider.dart';
import 'category_item.dart';
import 'trend_summary_card.dart';

class ExpenseCategoryList extends StatelessWidget {
  const ExpenseCategoryList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseDataProvider>(
      builder: (context, provider, child) {
        // Lấy danh mục hiện tại theo lựa chọn
        final currentCategories = provider.isShowingExpense
            ? provider.categories
            : provider.incomeCategories;

        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Hiển thị grid card khác nhau dựa vào loại biểu đồ
              if (provider.isShowingPieChart)
              // Grid card cho Phân bố (Pie Chart)
                Column(
                  children: [
                    // Tiêu đề
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Text(
                            provider.isShowingExpense
                                ? 'Chi tiêu theo danh mục'
                                : 'Thu nhập theo danh mục',
                            style: TextStyle(
                              color: provider.isShowingExpense
                                  ? Theme.of(context).colorScheme.primary
                                  : const Color(0xFF4CAF50),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Category list
                    if (currentCategories.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          provider.isShowingExpense
                              ? 'Chưa có giao dịch chi tiêu nào trong tháng này'
                              : 'Chưa có giao dịch thu nhập nào trong tháng này',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ...currentCategories.asMap().entries.map((entry) {
                        final index = entry.key;
                        final category = entry.value;
                        return CategoryItem(
                          category: category,
                          isHighlighted: provider.touchedIndex == index,
                          onTap: () {
                            if (provider.touchedIndex == index) {
                              provider.setTouchedIndex(-1);
                            } else {
                              provider.setTouchedIndex(index);
                            }
                          },
                        );
                      }).toList(),
                    const SizedBox(height: 8),
                  ],
                )
              else
              // Grid card mới cho Xu hướng (Bar Chart)
                TrendSummaryCard(provider: provider),
            ],
          ),
        );
      },
    );
  }
}

