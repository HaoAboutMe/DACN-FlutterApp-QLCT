import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../config/app_theme.dart';
import '../../../database/database_helper.dart';
import '../../../models/transaction.dart' as transaction_model;
import '../../../utils/currency_formatter.dart';
import '../models/expense_category.dart';
import '../models/daily_expense.dart';

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
    final allCategories = categoryMap.values
        .where((category) => category.amount > 0)
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    // Gộp các danh mục nhỏ hơn 1% thành "Các danh mục khác"
    _categories = _groupSmallCategories(allCategories);
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
    final allIncomeCategories = categoryMap.values
        .where((category) => category.amount > 0)
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    // Gộp các danh mục nhỏ hơn 1% thành "Các danh mục khác"
    _incomeCategories = _groupSmallCategories(allIncomeCategories);
  }

  // Gộp các danh mục nhỏ hơn 1% thành "Các danh mục khác"
  List<ExpenseCategory> _groupSmallCategories(List<ExpenseCategory> categories) {
    if (categories.isEmpty) return [];

    // Tách danh mục lớn (>= 1%) và nhỏ (< 1%)
    final largeCategories = categories.where((cat) => cat.percentage >= 1.0).toList();
    final smallCategories = categories.where((cat) => cat.percentage < 1.0).toList();

    // Nếu không có danh mục nhỏ, trả về danh sách gốc
    if (smallCategories.isEmpty) {
      return categories;
    }

    // Tính tổng các danh mục nhỏ
    final totalSmallAmount = smallCategories.fold(0.0, (sum, cat) => sum + cat.amount);
    final totalSmallPercentage = smallCategories.fold(0.0, (sum, cat) => sum + cat.percentage);

    // Tạo danh mục "Các danh mục khác"
    final otherCategory = ExpenseCategory(
      name: 'Các danh mục khác',
      amount: totalSmallAmount,
      icon: Icons.leaderboard_sharp,
      color: Colors.grey,
      percentage: totalSmallPercentage,
    );

    // Kết hợp danh mục lớn với danh mục "Khác"
    return [...largeCategories, otherCategory];
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

    // Clean the icon string
    String cleanedIcon = iconString.toLowerCase();
    if (cleanedIcon.startsWith('icons.')) {
      cleanedIcon = cleanedIcon.substring(6);
    }

    // Fallback to default icon mapping
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

    if (colorMap.containsKey(categoryName)) {
      return colorMap[categoryName]!;
    }

    return _generateColorFromId(categoryId);
  }

  // Lấy màu cho danh mục thu nhập
  Color _getColorForIncomeCategory(String categoryName, int categoryId) {
    final colorMap = {
      'Lương': const Color(0xFF4CAF50),
      'Thưởng': const Color(0xFF8BC34A),
      'Đầu tư': const Color(0xFF009688),
      'Kinh doanh': const Color(0xFF03A9F4),
      'Khác': const Color(0xFFFF9800),
    };

    if (colorMap.containsKey(categoryName)) {
      return colorMap[categoryName]!;
    }

    return _generateColorFromId(categoryId);
  }

  // Sinh màu dựa trên ID
  Color _generateColorFromId(int id) {
    final colorPalette = [
      Color(0xFFFFA726),
      Color(0xFF26C6DA),
      Color(0xFFBA68C8),
      Color(0xFF66BB6A),
      Color(0xFFF06292),
      Color(0xFF42A5F5),
      Color(0xFFFFD54F),
      Color(0xFF26A69A),
      Color(0xFFE57373),
      Color(0xFF4FC3F7),
      Color(0xFFAB47BC),
      Color(0xFFAED581),
      Color(0xFFEC407A),
      Color(0xFF64B5F6),
      Color(0xFFFFCA28),
      Color(0xFF4DB6AC),
      Color(0xFFEF5350),
      Color(0xFF29B6F6),
      Color(0xFF7E57C2),
      Color(0xFF81C784),
      Color(0xFFFFB74D),
      Color(0xFF4DD0E1),
      Color(0xFF9575CD),
      Color(0xFF9CCC65),
      Color(0xFFA1887F),
      Color(0xFF5C6BC0),
      Color(0xFF90A4AE),
      Color(0xFF8D6E63),
      Color(0xFF7986CB),
      Color(0xFF78909C),
    ];

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
    _touchedIndex = -1;
    await _calculateMonthlyComparison();
    notifyListeners();
  }

  void toggleMoneyVisibility() {
    _isMoneyVisible = !_isMoneyVisible;
    notifyListeners();
  }

  Future<void> reloadData() async {
    await _loadRealData();
  }
}

