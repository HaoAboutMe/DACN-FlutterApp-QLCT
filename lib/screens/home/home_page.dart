import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/user.dart';
import '../../models/transaction.dart' as transaction_model;
import '../../models/category.dart';
import 'widgets/greeting_appbar.dart';
import 'widgets/balance_overview.dart';
import 'widgets/quick_actions.dart';
import 'widgets/recent_transactions.dart';
import 'widgets/all_budgets_widget.dart';
import '../add_transaction/add_transaction_page.dart';
import '../add_loan/add_loan_page.dart';
import '../budget/budget_list_screen.dart';
import '../transaction/transaction_detail_screen.dart';
import '../main_navigation_wrapper.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
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

  // Budget progress data
  Map<String, dynamic>? _overallBudgetProgress;
  List<Map<String, dynamic>> _categoryBudgets = [];
  bool _hasCheckedBudget = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Called when app lifecycle changes - reload data when app becomes active
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshHomeData();
    }
  }

  /// Public method to refresh home data - can be called from MainNavigationWrapper
  Future<void> _refreshHomeData() async {
    debugPrint('🏠 HomePage: _refreshHomeData() called');
    if (!mounted) return;
    await _loadData();
  }

  /// Public method for external calls from MainNavigationWrapper
  Future<void> refreshData() async {
    debugPrint('🏠 HomePage: refreshData() called from external');
    if (!mounted) return;
    await _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get current user ID from SharedPreferences and load user data
      final currentUserId = await _databaseHelper.getCurrentUserId();
      final currentUser = await _databaseHelper.getUserById(currentUserId);

      if (currentUser != null) {
        _currentUser = currentUser;
      } else {
        // If user not found, get the first available user (fallback)
        final users = await _databaseHelper.getAllUsers();
        if (users.isNotEmpty) {
          _currentUser = users.first;
        }
      }

      // Load recent transactions
      _recentTransactions = await _databaseHelper.getRecentTransactions(limit: 10);

      // Load categories mapping
      final categories = await _databaseHelper.getAllCategories();
      _categoriesMap = {for (var category in categories) category.id!: category};

      // Calculate overview statistics and current balance
      await _calculateOverviewStats();
      await _updateCurrentBalance();
      await _loadBudgetProgress();

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

  /// Tải dữ liệu tiến độ ngân sách
  Future<void> _loadBudgetProgress() async {
    try {
      // Lấy tiến độ ngân sách tổng
      final budgetProgress = await _databaseHelper.getOverallBudgetProgress();

      // Lấy danh sách ngân sách theo danh mục
      final categoryBudgets = await _databaseHelper.getBudgetProgress();

      setState(() {
        _overallBudgetProgress = budgetProgress;
        _categoryBudgets = categoryBudgets;
        _hasCheckedBudget = true;
      });

      // Kiểm tra và hiển thị cảnh báo nếu vượt hạn mức
      if (budgetProgress != null && budgetProgress['isOverBudget'] == true) {
        _showOverBudgetWarning();
      }
    } catch (e) {
      debugPrint('Error loading budget progress: $e');
    }
  }

  /// Hiển thị cảnh báo khi vượt hạn mức chi tiêu
  void _showOverBudgetWarning() {
    if (!mounted) return;

    // Chỉ hiển thị một lần khi load data
    if (_hasCheckedBudget) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cảnh báo: Đã vượt hạn mức chi tiêu!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Xem',
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BudgetListScreen(),
                  ),
                ).then((_) => _loadBudgetProgress());
              },
            ),
          ),
        );
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

      // Calculate income and expense from transactions (unchanged)
      for (final transaction in allTransactions) {
        switch (transaction.type) {
          case 'income':
          case 'debt_collected':
            _totalIncome += transaction.amount;
            break;
          case 'expense':
          case 'debt_paid':
            _totalExpense += transaction.amount;
            break;
        // Remove loan calculations from transactions as we'll calculate directly from loans table
        }
      }

      // Calculate loan statistics directly from loans table to include both old and new loans
      await _calculateLoanStats();
    } catch (e) {
      debugPrint('Error calculating overview stats: $e');
    }
  }

  /// Calculate loan statistics directly from loans table
  /// This includes both old debts (isOldDebt = 1) and new loans (isOldDebt = 0)
  Future<void> _calculateLoanStats() async {
    try {
      final allLoans = await _databaseHelper.getAllLoans();

      _totalLent = 0;
      _totalBorrowed = 0;

      for (final loan in allLoans) {
        // Only count active loans (not paid/completed)
        if (loan.status == 'active') {
          if (loan.loanType == 'lend') {
            _totalLent += loan.amount;
          } else if (loan.loanType == 'borrow') {
            _totalBorrowed += loan.amount;
          }
        }
      }
    } catch (e) {
      debugPrint('Error calculating loan stats: $e');
    }
  }

  /// Lấy số dư hiện tại của user từ database (không tính toán lại)
  /// Số dư đã được cập nhật chính xác qua các phương thức updateUserBalanceAfterTransaction
  Future<void> _updateCurrentBalance() async {
    try {
      // Get current user ID from SharedPreferences
      final currentUserId = await _databaseHelper.getCurrentUserId();

      // Lấy số dư hiện tại từ database (đã được cập nhật chính xác)
      final currentUser = await _databaseHelper.getUserById(currentUserId);
      if (currentUser != null) {
        // Chỉ cập nhật UI state, không modify database
        setState(() {
          _currentUser = currentUser;
        });
        debugPrint('Current balance for user ID $currentUserId: ${currentUser.balance}');
      } else {
        debugPrint('Warning: Current user with ID $currentUserId not found');
      }
    } catch (e) {
      debugPrint('Error getting current balance: $e');
    }
  }

  void _toggleBalanceVisibility() {
    setState(() {
      _isBalanceVisible = !_isBalanceVisible;
    });
  }

  Future<void> _navigateToAddTransaction(String transactionType) async {
    Widget targetPage;

    // Navigate to appropriate page based on transaction type
    if (transactionType == 'loan_given' || transactionType == 'loan_received') {
      // Navigate to AddLoanPage for loan transactions
      targetPage = AddLoanPage(preselectedType: transactionType);
    } else {
      // Navigate to AddTransactionPage for income/expense transactions
      targetPage = AddTransactionPage(preselectedType: transactionType);
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => targetPage),
    );

    // ✅ REALTIME: Refresh data if transaction/loan was successfully added
    if (result == true) {
      debugPrint('🔄 HomePage: Transaction/Loan added successfully, refreshing data...');
      await _refreshHomeData();
    }
  }

  void _handleNotificationPressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tính năng thông báo sẽ được phát triển sau')),
    );
  }

  /// Navigate to transaction detail screen and refresh data when returning
  Future<void> _navigateToTransactionDetail(transaction_model.Transaction transaction) async {
    debugPrint('🔍 HomePage: Navigating to TransactionDetailScreen for transaction: ${transaction.id}');

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionDetailScreen(transaction: transaction),
      ),
    );

    // ✅ REALTIME: Refresh data if transaction was modified or deleted
    if (result == true && mounted) {
      debugPrint('🔄 HomePage: Transaction was modified, refreshing data...');
      await _refreshHomeData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: GreetingAppBar(
        currentUser: _currentUser,
        onNotificationPressed: _handleNotificationPressed,
      ),
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary,
          ),
        ),
      )
          : RefreshIndicator(
              onRefresh: _refreshHomeData,
              color: Theme.of(context).colorScheme.primary,
              backgroundColor: Theme.of(context).colorScheme.surface,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
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

                      // Hiển thị tất cả ngân sách đang hoạt động
                      if (_overallBudgetProgress != null || _categoryBudgets.isNotEmpty)
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: AllBudgetsWidget(
                            overallBudget: _overallBudgetProgress,
                            categoryBudgets: _categoryBudgets,
                            onRefresh: _loadBudgetProgress,
                          ),
                        ),

                      if (_overallBudgetProgress != null || _categoryBudgets.isNotEmpty)
                        const SizedBox(height: 24),

                      QuickActions(
                        onIncomePressed: () => _navigateToAddTransaction('income'),
                        onExpensePressed: () => _navigateToAddTransaction('expense'),
                        onLoanGivenPressed: () => _navigateToAddTransaction('loan_given'),
                        onLoanReceivedPressed: () => _navigateToAddTransaction('loan_received'),
                      ),
                      const SizedBox(height: 24),

                      RecentTransactions(
                        transactions: _recentTransactions,
                        categoriesMap: _categoriesMap,
                        onViewAllPressed: () {
                          // Chuyển sang tab Giao dịch (index 1) thay vì push route mới
                          mainNavigationKey.currentState?.switchToTab(1);
                        },
                        onTransactionTap: _navigateToTransactionDetail,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
