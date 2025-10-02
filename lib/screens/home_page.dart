import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/user.dart';
import '../models/transaction.dart' as transaction_model;
import '../models/category.dart';
import 'home/home_colors.dart';
import 'home/widgets/greeting_appbar.dart';
import 'home/widgets/balance_overview.dart';
import 'home/widgets/quick_actions.dart';
import 'home/widgets/recent_transactions.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  User? _currentUser;
  List<transaction_model.Transaction> _recentTransactions = [];
  Map<int, Category> _categoriesMap = {};
  bool _isLoading = true;
  bool _isBalanceVisible = true;

  // Overview statistics
  double _totalIncome = 0;
  double _totalExpense = 0;
  double _totalLent = 0;
  double _totalBorrowed = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Load user data
      final users = await _databaseHelper.getAllUsers();
      if (users.isNotEmpty) {
        _currentUser = users.first;
      }

      // Load recent transactions
      _recentTransactions = await _databaseHelper.getRecentTransactions(limit: 10);

      // Load categories mapping
      final categories = await _databaseHelper.getAllCategories();
      _categoriesMap = {for (var category in categories) category.id!: category};

      // Calculate overview statistics
      await _calculateOverviewStats();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading HomePage data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _calculateOverviewStats() async {
    try {
      final allTransactions = await _databaseHelper.getAllTransactions();

      _totalIncome = 0;
      _totalExpense = 0;
      _totalLent = 0;
      _totalBorrowed = 0;

      for (final transaction in allTransactions) {
        switch (transaction.type) {
          case 'income':
          case 'debt_collected':
            _totalIncome += transaction.amount;
            break;
          case 'expense':
            _totalExpense += transaction.amount;
            break;
          case 'loan_given':
            _totalLent += transaction.amount;
            break;
          case 'loan_received':
            _totalBorrowed += transaction.amount;
            break;
        }
      }
    } catch (e) {
      debugPrint('Error calculating overview stats: $e');
    }
  }

  void _toggleBalanceVisibility() {
    setState(() {
      _isBalanceVisible = !_isBalanceVisible;
    });
  }

  void _showComingSoonSnackBar(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tính năng $feature sẽ được phát triển trong bước tiếp theo'),
        backgroundColor: HomeColors.primary,
      ),
    );
  }

  void _handleNotificationPressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tính năng thông báo sẽ được phát triển sau')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeColors.background,
      appBar: GreetingAppBar(
        currentUser: _currentUser,
        onNotificationPressed: _handleNotificationPressed,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(HomeColors.primary),
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    BalanceOverview(
                      currentUser: _currentUser,
                      isBalanceVisible: _isBalanceVisible,
                      onVisibilityToggle: _toggleBalanceVisibility,
                      totalIncome: _totalIncome,
                      totalExpense: _totalExpense,
                      totalLent: _totalLent,
                      totalBorrowed: _totalBorrowed,
                    ),
                    const SizedBox(height: 24),
                    QuickActions(
                      onIncomePressed: () => _showComingSoonSnackBar('thêm thu nhập'),
                      onExpensePressed: () => _showComingSoonSnackBar('thêm chi tiêu'),
                      onLoanGivenPressed: () => _showComingSoonSnackBar('cho vay'),
                      onLoanReceivedPressed: () => _showComingSoonSnackBar('đi vay'),
                    ),
                    const SizedBox(height: 24),
                    RecentTransactions(
                      transactions: _recentTransactions,
                      categoriesMap: _categoriesMap,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
