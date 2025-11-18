import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../config/app_theme.dart';
import '../../../utils/currency_formatter.dart';
import '../models/expense_category.dart';
import '../models/daily_expense.dart';
import '../providers/expense_data_provider.dart';

class SimpleChart extends StatelessWidget {
  const SimpleChart({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseDataProvider>(context);

    // Lấy danh mục hiện tại theo lựa chọn
    final currentCategories = provider.isShowingExpense
        ? provider.categories
        : provider.incomeCategories;

    final currentTotal = provider.isShowingExpense
        ? provider.totalExpense
        : provider.totalIncome;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
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
      child: currentCategories.isEmpty
          ? SizedBox(
        height: 200,
        child: Center(
          child: Text(
            provider.isShowingExpense
                ? 'Không có dữ liệu chi tiêu'
                : 'Không có dữ liệu thu nhập',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16),
          ),
        ),
      )
          : Column(
        children: [
          Text(
            provider.isShowingPieChart
                ? (provider.isShowingExpense
                ? 'Phân bổ chi tiêu theo danh mục'
                : 'Phân bổ thu nhập theo danh mục')
                : (provider.isShowingExpense
                ? 'So sánh chi tiêu theo tháng'
                : 'So sánh thu nhập theo tháng'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: provider.isShowingExpense
                  ? const Color(0xFFF44336)
                  : const Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(height: 20),
          provider.isShowingPieChart
              ? _buildSimplePieChart(context, provider, currentCategories, currentTotal)
              : _buildSimpleBarChart(context, provider),
        ],
      ),
    );
  }

  Widget _buildSimplePieChart(BuildContext context, ExpenseDataProvider provider, List<ExpenseCategory> categories, double total) {
    final legendHeight = categories.length <= 5 ? null : 120.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                enabled: true,
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  if (event is FlTapUpEvent && pieTouchResponse != null &&
                      pieTouchResponse.touchedSection != null) {
                    final touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                    if (provider.touchedIndex == touchedIndex) {
                      provider.setTouchedIndex(-1);
                    } else {
                      provider.setTouchedIndex(touchedIndex);
                    }
                  }
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 2,
              centerSpaceRadius: 50,
              sections: _createPieChartSections(context, provider, categories),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: provider.isShowingExpense
                ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                : AppTheme.accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  provider.isShowingExpense ? 'Tổng chi tiêu' : 'Tổng thu nhập',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)
              ),
              const SizedBox(height: 4),
              Text(
                provider.isMoneyVisible
                    ? CurrencyFormatter.formatAmount(total)
                    : '••••••••',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: provider.isShowingExpense ? AppTheme.primaryBlue : AppTheme.accentColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        legendHeight != null
            ? SizedBox(
          height: legendHeight,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: _buildPieChartLegend(context, provider, categories),
          ),
        )
            : _buildPieChartLegend(context, provider, categories),
      ],
    );
  }

  Widget _buildSimpleBarChart(BuildContext context, ExpenseDataProvider provider) {
    if (provider.dailyExpenses.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'Không có dữ liệu so sánh',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16),
          ),
        ),
      );
    }

    return SizedBox(
      height: 300,
      child: Column(
        children: [
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _getMaxY(provider.dailyExpenses),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipMargin: 8,
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      if (!provider.isMoneyVisible) {
                        return null;
                      }
                      return BarTooltipItem(
                        '${rod.toY.toStringAsFixed(1)} triệu đồng',
                        TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        if (value.toInt() < provider.dailyExpenses.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              provider.dailyExpenses[value.toInt()].period,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                      reservedSize: 32,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: _getMaxY(provider.dailyExpenses) / 4,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        return Text(
                          '${value.toStringAsFixed(1)}M',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        );
                      },
                      reservedSize: 40,
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3), width: 1),
                    left: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3), width: 1),
                  ),
                ),
                barGroups: provider.dailyExpenses.asMap().entries.map((entry) {
                  final index = entry.key;
                  final expense = entry.value;
                  final isCurrentMonth = index == provider.dailyExpenses.length - 1;

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: expense.amount,
                        color: isCurrentMonth
                            ? AppTheme.primaryBlue
                            : AppTheme.primaryBlue.withValues(alpha: 0.6),
                        width: 40,
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: isCurrentMonth
                              ? [AppTheme.primaryBlue, AppTheme.primaryBlue.withValues(alpha: 0.8)]
                              : [AppTheme.primaryBlue.withValues(alpha: 0.4), AppTheme.primaryBlue.withValues(alpha: 0.6)],
                        ),
                      ),
                    ],
                  );
                }).toList(),
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: _getMaxY(provider.dailyExpenses) / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2),
                      strokeWidth: 1,
                    );
                  },
                  drawVerticalLine: false,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text('Tháng hiện tại', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
              const SizedBox(width: 16),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text('Tháng trước', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  double _getMaxY(List<DailyExpense> expenses) {
    if (expenses.isEmpty) return 5.0;
    final maxVal = expenses.map((e) => e.amount).reduce(math.max);
    return (maxVal * 1.3).ceilToDouble();
  }

  List<PieChartSectionData> _createPieChartSections(BuildContext context, ExpenseDataProvider provider, List<ExpenseCategory> categories) {
    return categories.take(8).toList().asMap().entries.map((entry) {
      final index = entry.key;
      final category = entry.value;
      final isTouched = provider.touchedIndex == index;
      final fontSize = isTouched ? 16.0 : 12.0;
      final radius = isTouched ? 65.0 : 55.0;

      return PieChartSectionData(
        color: category.color,
        value: category.percentage,
        title: isTouched ? '${category.percentage.toStringAsFixed(1)}%' : '',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onPrimary,
          shadows: [
            Shadow(
                color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.5),
                offset: const Offset(1, 1),
                blurRadius: 2
            ),
          ],
        ),
        badgeWidget: isTouched
            ? Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(category.icon, color: category.color, size: 16),
              const SizedBox(height: 2),
              Text(
                category.name,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: category.color,
                ),
              ),
              Text(
                provider.isMoneyVisible
                    ? CurrencyFormatter.formatAmount(category.amount)
                    : '••••••••',
                style: TextStyle(
                  fontSize: 8,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        )
            : null,
        badgePositionPercentageOffset: 1.3,
      );
    }).toList();
  }

  Widget _buildPieChartLegend(BuildContext context, ExpenseDataProvider provider, List<ExpenseCategory> categories) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 100),
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          children: categories.take(8).toList().asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value;
            final isHighlighted = provider.touchedIndex == index;

            return GestureDetector(
              onTap: () {
                if (provider.touchedIndex == index) {
                  provider.setTouchedIndex(-1);
                } else {
                  provider.setTouchedIndex(index);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isHighlighted
                      ? Border.all(color: category.color, width: 2)
                      : Border.all(color: Colors.transparent, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: category.color,
                        shape: BoxShape.circle,
                        border: isHighlighted
                            ? Border.all(color: Theme.of(context).colorScheme.outline, width: 2)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          category.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '${category.percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

