import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/app_theme.dart';
import '../../database/database_helper.dart';
import '../../models/transaction.dart' as transaction_model;
import '../../utils/currency_formatter.dart';
import '../machine_learning_statistics/spending_prediction_screen.dart';

// Data models
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

// Provider class
class ExpenseDataProvider extends ChangeNotifier {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _isShowingPieChart = true;
  bool _isLoading = false;
  int _touchedIndex = -1;
  bool _isShowingExpense = true; // true: chi tiêu, false: thu nhập
  bool _isMoneyVisible = true; // true: hiện số tiền, false: ẩn số tiền

  DateTime get selectedMonth => _selectedMonth;
  bool get isShowingPieChart => _isShowingPieChart;
  bool get isLoading => _isLoading;
  int get touchedIndex => _touchedIndex;
  bool get isShowingExpense => _isShowingExpense;
  bool get isMoneyVisible => _isMoneyVisible;

  List<ExpenseCategory> _categories = [];
  List<ExpenseCategory> _incomeCategories = [];
  List<DailyExpense> _dailyExpenses = [];

  List<ExpenseCategory> get categories => _categories;
  List<ExpenseCategory> get incomeCategories => _incomeCategories;
  List<DailyExpense> get dailyExpenses => _dailyExpenses;

  double get totalExpense => _categories.fold(0.0, (s, c) => s + c.amount);
  double _totalIncome = 0;
  double get totalIncome => _totalIncome;

  ExpenseDataProvider() {
    _loadRealData();
  }

  // Lấy dữ liệu thật từ database
  Future<void> _loadRealData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

      // Lấy giao dịch chi tiêu và thu nhập
      final expenseTransactions = await _getTransactionsForMonth(firstDayOfMonth, lastDayOfMonth, 'expense');
      final incomeTransactions = await _getTransactionsForMonth(firstDayOfMonth, lastDayOfMonth, 'income');

      // Tính tổng thu nhập
      _totalIncome = incomeTransactions.fold(0.0, (sum, transaction) => sum + transaction.amount);

      print('Thu nhập tháng ${_selectedMonth.month}/${_selectedMonth.year}: ${CurrencyFormatter.formatAmount(_totalIncome)}');
      print('Số giao dịch thu nhập: ${incomeTransactions.length}');

      // Tính toán chi tiêu theo danh mục
      await _calculateCategoryExpenses(expenseTransactions);

      // Tính toán thu nhập theo danh mục
      await _calculateIncomeCategories(incomeTransactions);

      // Tính toán so sánh theo tháng
      await _calculateMonthlyComparison();

    } catch (e) {
      print('Lỗi khi tải dữ liệu thống kê: $e');
      _categories = [];
      _dailyExpenses = [];
      _totalIncome = 0;
    }

    _isLoading = false;
    notifyListeners();
  }

  // Lấy giao dịch theo loại (expense/income)
  Future<List<transaction_model.Transaction>> _getTransactionsForMonth(
      DateTime startDate, DateTime endDate, String type) async {
    final dbHelper = DatabaseHelper();
    final db = await dbHelper.database;

    final result = await db.rawQuery('''
      SELECT t.*, c.name as categoryName, c.icon as categoryIcon
      FROM transactions t
      LEFT JOIN categories c ON t.categoryId = c.id
      WHERE t.type = ? 
      AND t.date BETWEEN ? AND ?
      ORDER BY t.date DESC
    ''', [
      type,
      DateFormat('yyyy-MM-dd').format(startDate),
      DateFormat('yyyy-MM-dd').format(endDate),
    ]);

    return result.map((map) => transaction_model.Transaction.fromMap(map)).toList();
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
      final categoryName = categoryData['name'] as String;
      categoryMap[categoryId] = ExpenseCategory(
        name: categoryName,
        amount: 0,
        icon: _getIconFromString(categoryData['icon'] as String),
        color: _getColorForCategory(categoryName, categoryId),
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
  }

  // Tính toán thu nhập theo danh mục
  Future<void> _calculateIncomeCategories(List<transaction_model.Transaction> transactions) async {
    final Map<int, ExpenseCategory> categoryMap = {};
    final dbHelper = DatabaseHelper();
    final db = await dbHelper.database;

    // Lấy tất cả danh mục thu nhập
    final categoriesResult = await db.query('categories', where: 'type = ?', whereArgs: ['income']);

    // Khởi tạo danh mục với số tiền = 0
    for (final categoryData in categoriesResult) {
      final categoryId = categoryData['id'] as int;
      final categoryName = categoryData['name'] as String;
      categoryMap[categoryId] = ExpenseCategory(
        name: categoryName,
        amount: 0,
        icon: _getIconFromString(categoryData['icon'] as String),
        color: _getColorForIncomeCategory(categoryName, categoryId),
        percentage: 0,
      );
    }

    // Tính tổng thu nhập cho mỗi danh mục
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

    // Chỉ lấy danh mục có thu nhập > 0
    _incomeCategories = categoryMap.values
        .where((category) => category.amount > 0)
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
  }

  // Tính toán so sánh theo tháng dựa trên dữ liệu giao dịch thực tế
  Future<void> _calculateMonthlyComparison() async {
    final currentMonth = _selectedMonth;
    final previousMonth = DateTime(currentMonth.year, currentMonth.month - 1);

    // Lấy dữ liệu theo loại (chi tiêu hoặc thu nhập) từ transaction dates thực tế
    final currentMonthTotal = await getTotalForMonth(currentMonth, _isShowingExpense ? 'expense' : 'income');
    final previousMonthTotal = await getTotalForMonth(previousMonth, _isShowingExpense ? 'expense' : 'income');

    _dailyExpenses = [
      DailyExpense(
        period: 'T${previousMonth.month}',
        amount: previousMonthTotal / 1000000, // Convert sang triệu đồng
      ),
      DailyExpense(
        period: 'T${currentMonth.month}',
        amount: currentMonthTotal / 1000000, // Convert sang triệu đồng
      ),
    ];
  }

  // Lấy tổng chi tiêu hoặc thu nhập trong một tháng dựa trên ngày giao dịch thực tế
  Future<double> getTotalForMonth(DateTime month, String type) async {
    final dbHelper = DatabaseHelper();
    final db = await dbHelper.database;

    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM transactions 
      WHERE type = ? 
      AND date(date) >= date(?) 
      AND date(date) <= date(?)
    ''', [
      type, // 'expense' hoặc 'income'
      DateFormat('yyyy-MM-dd').format(firstDay),
      DateFormat('yyyy-MM-dd').format(lastDay),
    ]);

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // Chuyển đổi string icon thành IconData
  IconData _getIconFromString(String iconString) {
    // Try to parse as codePoint (for newer categories)
    final codePoint = int.tryParse(iconString);
    if (codePoint != null) {
      return IconData(codePoint, fontFamily: 'MaterialIcons');
    }

    // Clean the icon string: remove "Icons." or "icons." prefix and convert to lowercase
    String cleanedIcon = iconString.toLowerCase();
    if (cleanedIcon.startsWith('icons.')) {
      cleanedIcon = cleanedIcon.substring(6);
    }

    // Fallback to default icon mapping (for legacy categories)
    const iconMap = {
      'restaurant': Icons.restaurant,
      'food': Icons.restaurant,
      'local_gas_station': Icons.local_gas_station,
      'transport': Icons.directions_car,
      'directions_car': Icons.directions_car,
      'shopping_cart': Icons.shopping_cart,
      'shopping_bag': Icons.shopping_bag,
      'shopping': Icons.shopping_cart,
      'receipt': Icons.receipt,
      'movie': Icons.movie,
      'entertainment': Icons.movie,
      'medical_services': Icons.medical_services,
      'health': Icons.medical_services,
      'school': Icons.school,
      'education': Icons.school,
      'home': Icons.home,
      'phone': Icons.phone,
      'electrical_services': Icons.electrical_services,
      'utilities': Icons.electrical_services,
      'water_drop': Icons.water_drop,
      'work': Icons.work,
      'business': Icons.work,
      'savings': Icons.savings,
      'card_giftcard': Icons.card_giftcard,
      'travel': Icons.flight,
      'flight': Icons.flight,
      'attach_money': Icons.attach_money,
      'trending_up': Icons.trending_up,
      'fitness_center': Icons.fitness_center,
      'more_horiz': Icons.more_horiz,
      'other': Icons.category,
      'category': Icons.category,
    };

    return iconMap[cleanedIcon] ?? Icons.category;
  }

  // Lấy màu cho danh mục chi tiêu
  Color _getColorForCategory(String categoryName, int categoryId) {
    // Màu cho các danh mục mặc định
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

    // Nếu là danh mục mặc định, dùng màu đã định nghĩa
    if (colorMap.containsKey(categoryName)) {
      return colorMap[categoryName]!;
    }

    // Với danh mục do người dùng tạo, sinh màu dựa trên ID để đảm bảo tính ổn định
    return _generateColorFromId(categoryId);
  }

  // Lấy màu cho danh mục thu nhập
  Color _getColorForIncomeCategory(String categoryName, int categoryId) {
    // Màu cho các danh mục mặc định
    final colorMap = {
      'Lương': const Color(0xFF4CAF50),
      'Thưởng': const Color(0xFF8BC34A),
      'Đầu tư': const Color(0xFF009688),
      'Kinh doanh': const Color(0xFF03A9F4),
      'Khác': const Color(0xFFFF9800),
    };

    // Nếu là danh mục mặc định, dùng màu đã định nghĩa
    if (colorMap.containsKey(categoryName)) {
      return colorMap[categoryName]!;
    }

    // Với danh mục do người dùng tạo, sinh màu dựa trên ID để đảm bảo tính ổn định
    return _generateColorFromId(categoryId);
  }

  // Sinh màu ngẫu nhiên nhưng ổn định dựa trên ID
  // Đảm bảo màu có độ tương phản tốt và dễ phân biệt
  Color _generateColorFromId(int id) {
    // Danh sách màu đẹp và dễ phân biệt (Material Design palette)
    final colorPalette = [
      Color(0xFFFFA726), // Orange 400
      Color(0xFF26C6DA), // Cyan 400
      Color(0xFFBA68C8), // Purple 300
      Color(0xFF66BB6A), // Green 400
      Color(0xFFF06292), // Pink 300
      Color(0xFF42A5F5), // Blue 400
      Color(0xFFFFD54F), // Amber 300
      Color(0xFF26A69A), // Teal 400
      Color(0xFFE57373), // Red 300
      Color(0xFF4FC3F7), // Light Blue 300
      Color(0xFFAB47BC), // Purple 400
      Color(0xFFAED581), // Light Green 300
      Color(0xFFEC407A), // Pink 400
      Color(0xFF64B5F6), // Blue 300
      Color(0xFFFFCA28), // Amber 400
      Color(0xFF4DB6AC), // Teal 300
      Color(0xFFEF5350), // Red 400
      Color(0xFF29B6F6), // Light Blue 400
      Color(0xFF7E57C2), // Deep Purple 400
      Color(0xFF81C784), // Green 300
      Color(0xFFFFB74D), // Orange 300
      Color(0xFF4DD0E1), // Cyan 300
      Color(0xFF9575CD), // Deep Purple 300
      Color(0xFF9CCC65), // Light Green 400
      Color(0xFFA1887F), // Brown 300
      Color(0xFF5C6BC0), // Indigo 400
      Color(0xFF90A4AE), // Blue Grey 300
      Color(0xFF8D6E63), // Brown 400
      Color(0xFF7986CB), // Indigo 300
      Color(0xFF78909C), // Blue Grey 400
    ];

    /// Ví dụ id là 10 thì sẽ là colorPalltete[10] --> màu: LightBlue
    return colorPalette[id % colorPalette.length];
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

  void toggleExpenseIncome(bool showExpense) async {
    _isShowingExpense = showExpense;
    _touchedIndex = -1; // Reset selection
    await _calculateMonthlyComparison(); // Reload dữ liệu biểu đồ cột
    notifyListeners();
  }

  void toggleMoneyVisibility() {
    _isMoneyVisible = !_isMoneyVisible;
    notifyListeners();
  }

  // Public method to reload data (for pull-to-refresh and manual refresh)
  Future<void> reloadData() async {
    await _loadRealData();
  }
}

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
                          const _MonthSelectorSection(),
                          const _MonthPickerSection(),
                          const _PredictionButton(),
                          const _ExpenseSummaryCard(),
                          const _ComparisonCard(),
                          const _SimpleChart(),
                          const _ExpenseCategoryList(),
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
              Text(
                'Tình hình thu chi',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              // Toggle button cho biểu đồ
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  ),
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
                          color: provider.isShowingPieChart
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.pie_chart,
                              color: provider.isShowingPieChart
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.primary,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Phân bổ',
                              style: TextStyle(
                                color: provider.isShowingPieChart
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context).colorScheme.primary,
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
                          color: !provider.isShowingPieChart
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bar_chart,
                              color: !provider.isShowingPieChart
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.primary,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Xu hướng',
                              style: TextStyle(
                                color: !provider.isShowingPieChart
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context).colorScheme.primary,
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
                icon: Icon(
                  Icons.chevron_left,
                  size: 30,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'Tháng ${provider.selectedMonth.month}/${provider.selectedMonth.year}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => provider.changeMonth(true),
                icon: Icon(
                  Icons.chevron_right,
                  size: 30,
                  color: Theme.of(context).colorScheme.primary,
                ),
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
    return Consumer<ExpenseDataProvider>(
      builder: (context, provider, child) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => provider.toggleExpenseIncome(true), // Chọn chi tiêu
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: provider.isShowingExpense
                            ? const Color(0xFFF44336) // Màu đỏ cho chi tiêu
                            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                        width: provider.isShowingExpense ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: provider.isShowingExpense
                              ? const Color(0xFFF44336).withValues(alpha: 0.1)
                              : Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
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
                            Icon(Icons.trending_down,
                                color: provider.isShowingExpense
                                    ? const Color(0xFFF44336)
                                    : Theme.of(context).colorScheme.outline,
                                size: 16),
                            const SizedBox(width: 4),
                            Text('Chi tiêu',
                                style: TextStyle(
                                  color: provider.isShowingExpense
                                      ? const Color(0xFFF44336)
                                      : Theme.of(context).colorScheme.outline,
                                  fontWeight: provider.isShowingExpense ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 14,
                                )),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          provider.isMoneyVisible
                              ? CurrencyFormatter.formatAmount(provider.totalExpense)
                              : '••••••••',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: provider.isShowingExpense
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => provider.toggleExpenseIncome(false), // Chọn thu nhập
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: !provider.isShowingExpense
                            ? const Color(0xFF4CAF50) // Màu xanh cho thu nhập
                            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                        width: !provider.isShowingExpense ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: !provider.isShowingExpense
                              ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                              : Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
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
                            Icon(Icons.trending_up,
                                color: !provider.isShowingExpense
                                    ? const Color(0xFF4CAF50)
                                    : Theme.of(context).colorScheme.outline,
                                size: 16),
                            const SizedBox(width: 4),
                            Text('Thu nhập',
                                style: TextStyle(
                                  color: !provider.isShowingExpense
                                      ? const Color(0xFF4CAF50)
                                      : Theme.of(context).colorScheme.outline,
                                  fontWeight: !provider.isShowingExpense ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 14,
                                )),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          provider.isMoneyVisible
                              ? CurrencyFormatter.formatAmount(provider.totalIncome)
                              : '••••••••',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: !provider.isShowingExpense
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseDataProvider>(context);
    final savings = provider.totalIncome - provider.totalExpense;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            savings >= 0 ? Icons.trending_up : Icons.trending_down,
            color: savings >= 0 ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              savings >= 0
                  ? 'Tiết kiệm được ${CurrencyFormatter.formatAmount(savings.abs())} trong tháng này'
                  : 'Chi vượt ${CurrencyFormatter.formatAmount(savings.abs())} so với thu nhập',
              style: TextStyle(
                color: savings >= 0 ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleChart extends StatelessWidget {
  const _SimpleChart();

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
    // Tính toán chiều cao legend dựa trên số lượng danh mục
    final legendHeight = categories.length <= 5 ? null : 120.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Beautiful Pie Chart with fl_chart - Chiều cao cố định
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                enabled: true,
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  // Chỉ xử lý khi tap xuống (FlTapUpEvent) - click một lần
                  if (event is FlTapUpEvent && pieTouchResponse != null &&
                      pieTouchResponse.touchedSection != null) {
                    final touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                    // Toggle: nếu đang chọn thì bỏ chọn, nếu chưa chọn thì chọn
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
        // Center total display - Cố định
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
        // Legend - Cuộn được khi có nhiều danh mục
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
                      // Ẩn tooltip khi isMoneyVisible = false
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
          // Legend
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
    return (maxVal * 1.3).ceilToDouble(); // Thêm 30% không gian trên
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
        title: isTouched ? '${category.percentage.toStringAsFixed(1)}%' : '', // Chỉ hiển thị khi được chọn
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
                  color: Colors.transparent, // Luôn trong suốt
                  borderRadius: BorderRadius.circular(8),
                  border: isHighlighted
                      ? Border.all(color: category.color, width: 2) // Màu của danh mục khi highlight
                      : Border.all(color: Colors.transparent, width: 2), // Viền trong suốt khi không chọn
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
                            fontSize: 12, // Tăng từ 11 lên 12
                            fontWeight: FontWeight.bold, // Đổi từ w600 thành bold
                            color: Theme.of(context).colorScheme.onSurface, // Theme-aware color
                          ),
                        ),
                        Text(
                          '${category.percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 11, // Tăng từ 10 lên 11
                            color: Theme.of(context).colorScheme.onSurfaceVariant, // Theme-aware color
                            fontWeight: FontWeight.w600, // Thêm trọng lượng cho số
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

class _ExpenseCategoryList extends StatelessWidget {
  const _ExpenseCategoryList();

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
                        return _CategoryItem(
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
                _TrendSummaryCard(provider: provider),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final ExpenseCategory category;
  final bool isHighlighted;
  final VoidCallback? onTap;

  const _CategoryItem({
    required this.category,
    required this.isHighlighted,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseDataProvider>(
      builder: (context, provider, child) {
        return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.transparent, // Luôn trong suốt
              borderRadius: BorderRadius.circular(12),
              border: isHighlighted
                  ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) // Viền blue khi highlight
                  : Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2), width: 1), // Viền mờ khi không chọn
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    category.icon,
                    color: category.color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold, // Đậm hơn
                          fontSize: 15, // Tăng từ 14 lên 15
                          color: Theme.of(context).colorScheme.onSurface, // Theme-aware color
                        ),
                      ),
                      Text(
                        '${category.percentage.toStringAsFixed(1)}% của tổng ${provider.isShowingExpense ? "chi tiêu" : "thu nhập"}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant, // Theme-aware color
                          fontSize: 12,
                          fontWeight: FontWeight.w500, // Thêm trọng lượng
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      provider.isMoneyVisible
                          ? CurrencyFormatter.formatAmount(category.amount)
                          : '••••••••',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15, // Tăng từ 14 lên 15
                        color: isHighlighted ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onSurface, // Theme-aware colors
                      ),
                    ),
                    Container(
                      width: 60,
                      height: 4,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: category.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Widget hiển thị tổng quan xu hướng cho tab Xu hướng
class _TrendSummaryCard extends StatelessWidget {
  final ExpenseDataProvider provider;

  const _TrendSummaryCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    // Lấy tháng hiện tại và tháng trước từ provider
    final currentMonth = provider.selectedMonth;
    final previousMonth = DateTime(currentMonth.year, currentMonth.month - 1);

    // Lấy dữ liệu từ dailyExpenses (đã được tính toán chính xác từ database)
    // dailyExpenses[0] = tháng trước, dailyExpenses[1] = tháng hiện tại
    final previousMonthAmount = provider.dailyExpenses.isNotEmpty
        ? provider.dailyExpenses[0].amount * 1000000 // Tháng trước (index 0)
        : 0.0;

    final currentMonthAmount = provider.dailyExpenses.length >= 2
        ? provider.dailyExpenses[1].amount * 1000000 // Tháng hiện tại (index 1)
        : 0.0;

    // Tính chênh lệch giữa 2 tháng
    final difference = currentMonthAmount - previousMonthAmount;

    // Tính phần trăm thay đổi (với xử lý division by zero)
    final percentageChange = previousMonthAmount > 0
        ? ((currentMonthAmount - previousMonthAmount) / previousMonthAmount * 100)
        : (currentMonthAmount > 0 ? 100.0 : 0.0); // Nếu tháng trước = 0 và tháng này > 0 thì tăng 100%

    final isIncrease = difference > 0;
    final isDecrease = difference < 0;


    return Column(
      children: [
        // Tiêu đề
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.trending_up,
                color: provider.isShowingExpense
                    ? Theme.of(context).colorScheme.primary
                    : const Color(0xFF4CAF50),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Tổng quan xu hướng',
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

        // Grid các thông tin so sánh 2 tháng
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              // Hàng 1: Tháng trước (trái) và Tháng hiện tại (phải)
              Row(
                children: [
                  Expanded(
                    child: _TrendInfoCard(
                      icon: Icons.history,
                      iconColor: Theme.of(context).colorScheme.secondary,
                      title: 'Tháng ${previousMonth.month}/${previousMonth.year}',
                      value: CurrencyFormatter.formatAmount(previousMonthAmount),
                      subtitle: 'Tháng trước',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TrendInfoCard(
                      icon: Icons.calendar_month,
                      iconColor: Theme.of(context).colorScheme.primary,
                      title: 'Tháng ${currentMonth.month}/${currentMonth.year}',
                      value: CurrencyFormatter.formatAmount(currentMonthAmount),
                      subtitle: 'Tháng hiện tại',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Hàng 2: Chênh lệch và Phần trăm thay đổi
              Row(
                children: [
                  Expanded(
                    child: _TrendInfoCard(
                      icon: isIncrease
                          ? Icons.arrow_upward
                          : isDecrease
                          ? Icons.arrow_downward
                          : Icons.remove,
                      iconColor: isIncrease
                          ? Theme.of(context).colorScheme.error
                          : isDecrease
                          ? const Color(0xFF4CAF50)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      title: 'Chênh lệch',
                      value: CurrencyFormatter.formatAmount(difference.abs()),
                      subtitle: isIncrease
                          ? 'Tăng'
                          : isDecrease
                          ? 'Giảm'
                          : 'Không đổi',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TrendInfoCard(
                      icon: Icons.percent,
                      iconColor: isIncrease
                          ? Theme.of(context).colorScheme.error
                          : isDecrease
                          ? const Color(0xFF4CAF50)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      title: 'Thay đổi',
                      value: percentageChange == 0
                          ? '0%'
                          : '${percentageChange > 0 ? '+' : ''}${percentageChange.toStringAsFixed(1)}%',
                      subtitle: isIncrease
                          ? 'So với tháng trước'
                          : isDecrease
                          ? 'So với tháng trước'
                          : 'Ổn định',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// Widget card nhỏ hiển thị từng thông tin xu hướng
class _TrendInfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String subtitle;

  const _TrendInfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
class _PredictionButton extends StatelessWidget {
  const _PredictionButton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SpendingPredictionScreen(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? const [
                  Color(0xFF1E3A8A), // Dark blue
                  Color(0xFF3B82F6), // Blue
                ]
                    : const [
                  Color(0xFF3B82F6), // Blue
                  Color(0xFF60A5FA), // Light blue
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.analytics_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dự báo Chi tiêu',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Xem dự đoán chi tiêu trong tương lai',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

