import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/expense_data_provider.dart';
import 'widgets/month_selector_section.dart';
import 'widgets/month_picker_section.dart';
import 'widgets/expense_summary_card.dart';
import 'widgets/comparison_card.dart';
import 'widgets/simple_chart.dart';
import 'widgets/expense_category_list.dart';
import 'widgets/prediction_button.dart';

// Main screen widget
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late ExpenseDataProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = ExpenseDataProvider();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  /// Public method to reload data - called from navigation wrapper
  Future<void> refreshData() async {
    if (mounted) {
      await _provider.reloadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: const _StatisticsContent(),
    );
  }
}

class _StatisticsContent extends StatefulWidget {
  const _StatisticsContent();

  @override
  State<_StatisticsContent> createState() => _StatisticsContentState();
}

class _StatisticsContentState extends State<_StatisticsContent> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => false; // Don't keep state alive to force refresh

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload data when screen becomes visible again
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ExpenseDataProvider>(context, listen: false);
      provider.reloadData();
    });
  }

  Future<void> _handleRefresh() async {
    final provider = Provider.of<ExpenseDataProvider>(context, listen: false);
    await provider.reloadData();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Thống kê chi tiêu',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: isDark ? theme.scaffoldBackgroundColor : colorScheme.primary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onPrimary,
        ),
        actions: [
          Consumer<ExpenseDataProvider>(
            builder: (context, provider, child) {
              return IconButton(
                onPressed: () => provider.toggleMoneyVisibility(),
                icon: Icon(
                  provider.isMoneyVisible
                      ? Icons.visibility
                      : Icons.visibility_off,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                tooltip: provider.isMoneyVisible ? 'Ẩn số tiền' : 'Hiện số tiền',
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<ExpenseDataProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: _handleRefresh,
              color: Theme.of(context).colorScheme.primary,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bottomPadding = MediaQuery.of(context).viewInsets.bottom +
                      MediaQuery.of(context).padding.bottom;
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          const MonthSelectorSection(),
                          const MonthPickerSection(),
                          const PredictionButton(),
                          const ExpenseSummaryCard(),
                          const ComparisonCard(),
                          const SimpleChart(),
                          const ExpenseCategoryList(),
                          SizedBox(height: bottomPadding + 120), // Tăng padding để tránh overflow
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}


