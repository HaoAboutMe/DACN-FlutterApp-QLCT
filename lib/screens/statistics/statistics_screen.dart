import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../config/app_theme.dart';
import '../../database/database_helper.dart';
import '../../models/transaction.dart' as transaction_model;

class ExpenseDataProvider extends ChangeNotifier {
  DateTime _selectedMonth = DateTime(2025, 10);
  bool _isShowingPieChart = true;
  bool _isLoading = false;
  int _touchedIndex = -1;

  DateTime get selectedMonth => _selectedMonth;
  bool get isShowingPieChart => _isShowingPieChart;
  bool get isLoading => _isLoading;
  int get touchedIndex => _touchedIndex;

  List<ExpenseCategory> _categories = [];
  List<DailyExpense> _dailyExpenses = [];

  List<ExpenseCategory> get categories => _categories;
  List<DailyExpense> get dailyExpenses => _dailyExpenses;

  double _totalExpense = 0;
  double get totalExpense => _totalExpense;
  double _totalIncome = 0;
  double get totalIncome => _totalIncome;

  ExpenseDataProvider() {
    _loadRealData();
  }

  // Lấy dữ liệu thật từ database
  Future<void> _loadRealData() async {
    print('🔄 Statistics: Starting to load data...');
    _isLoading = true;
    notifyListeners();

    try {
       final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
       final lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

      print('📅 Statistics: Loading data for period: ${firstDayOfMonth.toString()} to ${lastDayOfMonth.toString()}');

      // Lấy giao dịch chi tiêu và thu nhập
      final expenseTransactions = await _getTransactionsForMonth(firstDayOfMonth, lastDayOfMonth, 'expense');
      final incomeTransactions = await _getTransactionsForMonth(firstDayOfMonth, lastDayOfMonth, 'income');

      print('💰 Statistics: Found ${expenseTransactions.length} expense transactions, ${incomeTransactions.length} income transactions');

      // Tính tổng thu nhập và chi tiêu từ tất cả transactions
      _totalIncome = incomeTransactions.fold(0.0, (sum, t) => sum + t.amount);
      _totalExpense = expenseTransactions.fold(0.0, (sum, t) => sum + t.amount);

      print('💵 Statistics: Total Income: $_totalIncome, Total Expense: $_totalExpense');

      // Tính toán chi tiêu theo danh mục
      await _calculateCategoryExpenses(expenseTransactions);

      print('📊 Statistics: Categories calculated: ${_categories.length} categories');
      for (var cat in _categories) {
        print('  - ${cat.name}: ${cat.amount} (${cat.percentage.toStringAsFixed(1)}%)');
      }

      // Tính toán so sánh theo tháng
      await _calculateMonthlyComparison();

    } catch (e) {
      print('❌ Statistics: Error loading data: $e');
      _categories = [];
      _dailyExpenses = [];
      _totalIncome = 0;
      _totalExpense = 0;
    }

    _isLoading = false;
    notifyListeners();
    print('✅ Statistics: Data loading completed');
  }

  // Lấy giao dịch theo loại (expense/income)
  Future<List<transaction_model.Transaction>> _getTransactionsForMonth(
    DateTime startDate, DateTime endDate, String type) async {
    print('🔍 Statistics: Querying transactions - Type: $type, From: $startDate, To: $endDate');

    final dbHelper = DatabaseHelper();
    final db = await dbHelper.database;

    // Sửa query để đảm bảo lấy đúng dữ liệu
    final result = await db.rawQuery('''
      SELECT t.*, c.name as categoryName, c.icon as categoryIcon
      FROM transactions t
      LEFT JOIN categories c ON t.categoryId = c.id
      WHERE t.type = ? 
      AND date(t.date) >= date(?) 
      AND date(t.date) <= date(?)
      ORDER BY t.date DESC
    ''', [
      type,
      DateFormat('yyyy-MM-dd').format(startDate),
      DateFormat('yyyy-MM-dd').format(endDate),
    ]);

    print('📊 Statistics: Query result for $type: ${result.length} records');
    if (result.isNotEmpty) {
      print('   Sample record: ${result.first}');
    }

    final transactions = result.map((map) => transaction_model.Transaction.fromMap(map)).toList();
    print('✅ Statistics: Converted ${transactions.length} $type transactions');

    return transactions;
  }

  // Tính toán chi tiêu theo danh mục
  Future<void> _calculateCategoryExpenses(List<transaction_model.Transaction> transactions) async {
    final Map<int, ExpenseCategory> categoryMap = {};
    final dbHelper = DatabaseHelper();
    final db = await dbHelper.database;

    // Lấy tất cả danh mục chi tiêu
    final categoriesResult = await db.query('categories', where: 'type = ?', whereArgs: ['expense']);

    // Khởi tạo danh mục với số tiền = 0
    for (final categoryData in categoriesResult) {
      final categoryId = categoryData['id'] as int;
      categoryMap[categoryId] = ExpenseCategory(
        name: categoryData['name'] as String,
        amount: 0,
        icon: _getIconFromString(categoryData['icon'] as String),
        color: _getColorForCategory(categoryData['name'] as String),
        percentage: 0,
      );
    }

    // Tính tổng chi tiêu cho mỗi danh mục
    for (final transaction in transactions) {
      final categoryId = transaction.categoryId;
      if (categoryId != null && categoryMap.containsKey(categoryId)) {
        categoryMap[categoryId] = categoryMap[categoryId]!.copyWith(
          amount: categoryMap[categoryId]!.amount + transaction.amount,
        );
      }
    }

    // Tính phần trăm
    final totalAmount = categoryMap.values.fold(0.0, (sum, cat) => sum + cat.amount);
    if (totalAmount > 0) {
      categoryMap.forEach((key, category) {
        categoryMap[key] = category.copyWith(
          percentage: (category.amount / totalAmount) * 100,
        );
      });
    }

    // Chỉ lấy danh mục có chi tiêu > 0
    _categories = categoryMap.values
        .where((category) => category.amount > 0)
        .toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));

    // Lọc bỏ các danh mục không muốn hiển thị trong biểu đồ (ví dụ: Mua sắm, Khác)
    final _excludedNames = {'Mua sắm', 'Khác'};
    _categories.removeWhere((c) => _excludedNames.contains(c.name));
  }

  // Tính toán so sánh theo tháng
  Future<void> _calculateMonthlyComparison() async {
    final currentMonth = _selectedMonth;
    final previousMonth = DateTime(currentMonth.year, currentMonth.month - 1);

    final currentMonthExpense = await _getTotalExpenseForMonth(currentMonth);
    final previousMonthExpense = await _getTotalExpenseForMonth(previousMonth);

    _dailyExpenses = [
      DailyExpense(
        period: 'T${previousMonth.month}',
        amount: previousMonthExpense / 1000000,
      ),
      DailyExpense(
        period: 'T${currentMonth.month}',
        amount: currentMonthExpense / 1000000,
      ),
    ];
  }

  // Lấy tổng chi tiêu trong một tháng
  Future<double> _getTotalExpenseForMonth(DateTime month) async {
    final dbHelper = DatabaseHelper();
    final db = await dbHelper.database;

    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM transactions 
      WHERE type = 'expense' 
      AND date(date) >= date(?) 
      AND date(date) <= date(?)
    ''', [
      DateFormat('yyyy-MM-dd').format(firstDay),
      DateFormat('yyyy-MM-dd').format(lastDay),
    ]);

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // Chuyển đổi string icon thành IconData
  IconData _getIconFromString(String iconString) {
    final iconMap = {
      'restaurant': Icons.restaurant,
      'local_gas_station': Icons.local_gas_station,
      'shopping_cart': Icons.shopping_cart,
      'receipt': Icons.receipt,
      'movie': Icons.movie,
      'medical_services': Icons.medical_services,
      'school': Icons.school,
      'home': Icons.home,
      'directions_car': Icons.directions_car,
      'phone': Icons.phone,
      'electrical_services': Icons.electrical_services,
      'water_drop': Icons.water_drop,
    };
    return iconMap[iconString] ?? Icons.category;
  }

  // Lấy màu cho danh mục theo theme app
  Color _getColorForCategory(String categoryName) {
    final colorMap = {
      'Ăn uống': const Color(0xFFFF8A65),
      'Di chuyển': AppTheme.secondaryBlue,
      'Mua sắm': AppTheme.accentColor,
      'Hóa đơn': const Color(0xFF4ECDC4),
      'Giải trí': const Color(0xFFFF9800),
      'Y tế': const Color(0xFFE91E63),
      'Giáo dục': const Color(0xFF9C27B0),
      'Nhà cửa': const Color(0xFF795548),
      'Xe cộ': const Color(0xFF607D8B),
      'Điện thoại': const Color(0xFF3F51B5),
      'Điện': const Color(0xFFFFEB3B),
      'Nước': const Color(0xFF2196F3),
    };
    return colorMap[categoryName] ?? AppTheme.primaryBlue;
  }

  void changeMonth(bool isNext) {
    _selectedMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + (isNext ? 1 : -1),
    );
    _loadRealData();
  }

  void toggleChartType(bool showPie) {
    _isShowingPieChart = showPie;
    notifyListeners();
  }

  void setTouchedIndex(int index) {
    _touchedIndex = index;
    notifyListeners();
  }
}

class ExpenseCategory {
  final String name;
  final double amount;
  final IconData icon;
  final Color color;
  final double percentage;

  ExpenseCategory({
    required this.name,
    required this.amount,
    required this.icon,
    required this.color,
    required this.percentage,
  });

  ExpenseCategory copyWith({
    String? name,
    double? amount,
    IconData? icon,
    Color? color,
    double? percentage,
  }) {
    return ExpenseCategory(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      percentage: percentage ?? this.percentage,
    );
  }
}

class DailyExpense {
  final String period;
  final double amount; // in millions for chart

  DailyExpense({required this.period, required this.amount});
}

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ExpenseDataProvider(),
      child: const _StatisticsContent(),
    );
  }
}

class _StatisticsContent extends StatelessWidget {
  const _StatisticsContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      body: SafeArea(
        child: Consumer<ExpenseDataProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                ),
              );
            }
            return SingleChildScrollView(
              child: Column(
                children: const [
                  _AppBar(),
                  _TopTabsSection(),
                  _MonthSelectorSection(),
                  _MonthPickerSection(),
                  _ExpenseSummaryCard(),
                  _ComparisonCard(),
                  _ChartSwitcher(),
                  _ExpenseCategoryList(),
                  SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  const _AppBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Text(
            'Lịch sử giao dịch',
            style: TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.visibility_outlined,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopTabsSection extends StatelessWidget {
  const _TopTabsSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time, color: AppTheme.primaryBlue, size: 16),
                const SizedBox(width: 4),
                Text('Hoạt động', style: TextStyle(color: AppTheme.primaryBlue)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bar_chart, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text('Thống kê', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthSelectorSection extends StatelessWidget {
  const _MonthSelectorSection();

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseDataProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text(
                'Tình hình thu chi',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const Spacer(),
              // Toggle button cho biểu đồ
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.lightSurfaceVariant,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => provider.toggleChartType(true),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: provider.isShowingPieChart ? AppTheme.primaryBlue : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.pie_chart,
                              color: provider.isShowingPieChart ? Colors.white : AppTheme.primaryBlue,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Phân bổ',
                              style: TextStyle(
                                color: provider.isShowingPieChart ? Colors.white : AppTheme.primaryBlue,
                                fontWeight: provider.isShowingPieChart ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => provider.toggleChartType(false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: !provider.isShowingPieChart ? AppTheme.primaryBlue : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bar_chart,
                              color: !provider.isShowingPieChart ? Colors.white : AppTheme.primaryBlue,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Xu hướng',
                              style: TextStyle(
                                color: !provider.isShowingPieChart ? Colors.white : AppTheme.primaryBlue,
                                fontWeight: !provider.isShowingPieChart ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MonthPickerSection extends StatelessWidget {
  const _MonthPickerSection();

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseDataProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => provider.changeMonth(false),
                icon: const Icon(Icons.chevron_left, size: 30),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Tháng ${provider.selectedMonth.month}/${provider.selectedMonth.year}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => provider.changeMonth(true),
                icon: const Icon(Icons.chevron_right, size: 30),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ExpenseSummaryCard extends StatelessWidget {
  const _ExpenseSummaryCard();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseDataProvider>(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.trending_down, color: AppTheme.primaryBlue, size: 16),
                      const SizedBox(width: 4),
                      const Text('Chi tiêu', style: TextStyle(color: Colors.grey)),
                      const Spacer(),
                      Icon(Icons.arrow_downward, color: Colors.green, size: 16),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${NumberFormat('#,###').format(provider.totalExpense.round())}đ',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.trending_up, color: AppTheme.accentColor, size: 16),
                      const SizedBox(width: 4),
                      const Text('Thu nhập', style: TextStyle(color: Colors.grey)),
                      const Spacer(),
                      provider.totalIncome > 0
                        ? Icon(Icons.arrow_upward, color: Colors.green, size: 16)
                        : Icon(Icons.remove, color: Colors.grey, size: 16),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${NumberFormat('#,###').format(provider.totalIncome.round())}đ',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.bar_chart, color: Colors.blue, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Giảm ${NumberFormat('#,###').format(1573600)}đ so với cùng kỳ tháng trước',
              style: const TextStyle(
                color: Colors.green,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }
}

class _ChartSwitcher extends StatelessWidget {
  const _ChartSwitcher();

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseDataProvider>(
      builder: (context, provider, child) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: provider.isShowingPieChart
              ? const _ExpensePieChart()
              : const _ExpenseBarChart(),
        );
      },
    );
  }
}

class _ExpensePieChart extends StatelessWidget {
  const _ExpensePieChart();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseDataProvider>(context);
    return Container(
      key: const ValueKey('pie'),
      margin: const EdgeInsets.all(16),
      height: 320,
      // Rounded card-like container so chart appears with borderRadius and shadow
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.primaryBlue.withOpacity(0.06), Colors.white],
            ),
            color: Colors.white,
          ),
          child: provider.categories.isEmpty
              ? const Center(
                  child: Text(
                    'Không có dữ liệu',
                    style: TextStyle(color: Colors.black54, fontSize: 16),
                  ),
                )
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    // Custom painter draws dashed separators at slice boundaries
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _PieSeparatorPainter(
                          percentages: provider.categories.map((c) => c.amount).toList(),
                          centerSpaceRadius: 60,
                          outerRadius: 100,
                          selectedIndex: provider.touchedIndex,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ),

                    Center(
                      child: SizedBox(
                        width: 220,
                        height: 220,
                        child: PieChart(
                          PieChartData(
                            pieTouchData: PieTouchData(
                              enabled: true,
                              touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                if (event is FlTapUpEvent &&
                                    pieTouchResponse != null &&
                                    pieTouchResponse.touchedSection != null) {
                                  final sectionIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;

                                  if (provider.touchedIndex == sectionIndex) {
                                    provider.setTouchedIndex(-1);
                                  } else {
                                    provider.setTouchedIndex(sectionIndex);
                                  }
                                }
                              },
                            ),
                            borderData: FlBorderData(show: false),
                            sectionsSpace: 1,
                            centerSpaceRadius: 60,
                            startDegreeOffset: -90,
                            sections: _createPieChartSections(provider),
                          ),
                        ),
                      ),
                    ),

                    // Labels ngoài biểu đồ - giống hình (nhỏ nhất & lớn nhất)
                    ..._buildLabelsLikeInImage(provider),
                  ],
                ),
        ),
      ),
    );
  }

  List<Widget> _buildLabelsLikeInImage(ExpenseDataProvider provider) {
    if (provider.categories.isEmpty) return [];

    List<Widget> labels = [];

    if (provider.categories.isNotEmpty) {
      final smallestCategory = provider.categories.last;
      labels.add(
        Positioned(
          left: 20,
          top: 40,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: smallestCategory.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(smallestCategory.icon, color: smallestCategory.color, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${smallestCategory.percentage.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: smallestCategory.color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                smallestCategory.name,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );

      final largestCategory = provider.categories.first;
      labels.add(
        Positioned(
          right: 20,
          bottom: 40,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: largestCategory.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(largestCategory.icon, color: largestCategory.color, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${largestCategory.percentage > 50 ? ">" : ""}${largestCategory.percentage.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: largestCategory.color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                largestCategory.name,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return labels;
  }

  List<PieChartSectionData> _createPieChartSections(ExpenseDataProvider provider) {
    final total = provider.categories.fold<double>(0, (s, c) => s + c.amount);
    if (total <= 0) return [];

    return provider.categories.asMap().entries.map((entry) {
      final index = entry.key;
      final category = entry.value;
      final isTouched = provider.touchedIndex == index;
      final percentage = (category.amount / total) * 100;

      return PieChartSectionData(
        color: category.color,
        value: category.amount, // use actual amount so slice angles are accurate
        title: '',
        radius: isTouched ? 78.0 : 60.0,
        borderSide: BorderSide(
          color: Colors.white,
          width: isTouched ? 3 : 2,
        ),
      );
    }).toList();
  }
}

// Custom painter to draw dashed separator lines between pie slices
class _PieSeparatorPainter extends CustomPainter {
  final List<double> percentages; // amounts (not percentages) - will be normalized
  final double centerSpaceRadius;
  final double outerRadius;
  final int selectedIndex;
  final Color color;

  _PieSeparatorPainter({
    required this.percentages,
    required this.centerSpaceRadius,
    required this.outerRadius,
    required this.selectedIndex,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (percentages.isEmpty) return;

    final total = percentages.fold<double>(0, (s, v) => s + v);
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);

    double startAngle = -math.pi / 2; // start at top
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (var i = 0; i < percentages.length; i++) {
      final sweep = (percentages[i] / total) * 2 * math.pi;
      final angle = startAngle + sweep; // boundary angle

      // draw dashed radial line from inner radius to outer radius at 'angle'
      final inner = center + Offset(math.cos(angle) * centerSpaceRadius, math.sin(angle) * centerSpaceRadius);
      final outer = center + Offset(math.cos(angle) * outerRadius, math.sin(angle) * outerRadius);

      _drawDashedLine(canvas, paint, inner, outer, dashLength: 6, gapLength: 4);

      startAngle += sweep;
    }
  }

  void _drawDashedLine(Canvas canvas, Paint paint, Offset p1, Offset p2, {double dashLength = 5, double gapLength = 3}) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    final dashCount = (distance / (dashLength + gapLength)).floor();
    final dashX = dx / distance * dashLength;
    final dashY = dy / distance * dashLength;
    final gapX = dx / distance * gapLength;
    final gapY = dy / distance * gapLength;

    var current = p1;
    final path = Path();
    for (var i = 0; i < dashCount; i++) {
      final next = Offset(current.dx + dashX, current.dy + dashY);
      path.moveTo(current.dx, current.dy);
      path.lineTo(next.dx, next.dy);
      current = Offset(next.dx + gapX, next.dy + gapY);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PieSeparatorPainter oldDelegate) {
    return oldDelegate.percentages != percentages || oldDelegate.selectedIndex != selectedIndex;
  }
}

class _ExpenseBarChart extends StatelessWidget {
  const _ExpenseBarChart();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseDataProvider>(context);
    return Container(
      key: const ValueKey('bar'),
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      height: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Xu hướng chi tiêu theo tháng',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 8),
          const Text('(Triệu đồng)', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),
          Expanded(
            child: provider.dailyExpenses.isEmpty
                ? const Center(
                    child: Text(
                      'Không có dữ liệu',
                      style: TextStyle(color: Colors.black54, fontSize: 16),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _getMaxY(provider.dailyExpenses),
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (group) => AppTheme.primaryBlue,
                          tooltipRoundedRadius: 8,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              '${rod.toY.toStringAsFixed(1)} triệu',
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < provider.dailyExpenses.length) {
                                return Text(
                                  provider.dailyExpenses[index].period,
                                  style: TextStyle(
                                    color: index == provider.dailyExpenses.length - 1
                                        ? AppTheme.primaryBlue
                                        : Colors.grey,
                                    fontSize: 14,
                                    fontWeight: index == provider.dailyExpenses.length - 1
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toStringAsFixed(1),
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1),
                          left: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1),
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
                              color: isCurrentMonth ? AppTheme.primaryBlue : AppTheme.secondaryBlue.withOpacity(0.7),
                              width: 40,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ],
                        );
                      }).toList(),
                      gridData: FlGridData(
                        show: true,
                        horizontalInterval: _getMaxY(provider.dailyExpenses) / 4,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey.withOpacity(0.2),
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
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              const Text('Tháng hiện tại', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  double _getMaxY(List<DailyExpense> expenses) {
    if (expenses.isEmpty) return 3.0;
    final maxVal = expenses.map((e) => e.amount).reduce(math.max);
    return (maxVal * 1.2).ceilToDouble();
  }
}

class _ExpenseCategoryList extends StatelessWidget {
  const _ExpenseCategoryList();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseDataProvider>(context);
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Tiêu đề
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Chi tiêu theo danh mục',
                  style: TextStyle(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          // Category list
          if (provider.categories.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Chưa có giao dịch nào trong tháng này',
                style: TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...provider.categories.asMap().entries.map((entry) {
              final index = entry.key;
              final category = entry.value;
              return _CategoryItem(
                category: category,
                isHighlighted: provider.touchedIndex == index,
              );
            }).toList(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final ExpenseCategory category;
  final bool isHighlighted;

  const _CategoryItem({
    required this.category,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: isHighlighted
              ? Colors.red
              : AppTheme.primaryBlue.withOpacity(0.2),
          width: isHighlighted ? 3 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isHighlighted
                ? Colors.red.withOpacity(0.2)
                : Colors.grey.withOpacity(0.05),
            blurRadius: isHighlighted ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: category.color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: isHighlighted ? [
                BoxShadow(
                  color: category.color.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ] : null,
            ),
            child: Icon(
              category.icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: TextStyle(
                    color: isHighlighted ? Colors.red : Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${category.percentage.toStringAsFixed(1)}% tổng chi tiêu',
                  style: TextStyle(
                    color: isHighlighted ? Colors.red.withOpacity(0.7) : Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${NumberFormat('#,###').format(category.amount.round())}đ',
                style: TextStyle(
                  color: isHighlighted ? Colors.red : AppTheme.primaryBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Icon(
                Icons.chevron_right,
                color: isHighlighted
                    ? Colors.red.withOpacity(0.7)
                    : Colors.grey.withOpacity(0.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
