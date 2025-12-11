import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/repositories/repositories.dart';
import '../../models/user.dart';
import '../../models/transaction.dart' as transaction_model;
import '../../models/category.dart';
import '../../providers/notification_provider.dart';
import '../../providers/currency_provider.dart';
import '../../services/widget_service.dart';
import 'widgets/greeting_appbar.dart';
import 'widgets/balance_overview.dart';
import 'widgets/quick_actions.dart';
import 'widgets/recent_transactions.dart';
import 'widgets/all_budgets_widget.dart';
import '../add_transaction/add_transaction_page.dart';
import '../add_loan/add_loan_page.dart';
import '../receipt_scan/receipt_scan_screen.dart';
import '../budget/budget_list_screen.dart';
import '../transaction/transaction_detail_screen.dart';
import '../notification/notification_list_screen.dart';
import '../main_navigation_wrapper.dart';

enum TimeFilter { week, month, year }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final TransactionRepository _transactionRepository = TransactionRepository();
  final CategoryRepository _categoryRepository = CategoryRepository();
  final UserRepository _userRepository = UserRepository();
  final BudgetRepository _budgetRepository = BudgetRepository();
  final LoanRepository _loanRepository = LoanRepository();

  User? _currentUser;
  List<transaction_model.Transaction> _recentTransactions = [];
  Map<int, Category> _categoriesMap = {};
  bool _isLoading = true;
  bool _isBalanceVisible = true;

  // Time filter for income/expense (default: month)
  TimeFilter _timeFilter = TimeFilter.month;

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
    
    // ✅ CẬP NHẬT WIDGET KHI REFRESH
    try {
      await WidgetService.updateWidgetData();
    } catch (e) {
      debugPrint('❌ Error updating widget: $e');
    }
  }

  /// Public method for external calls from MainNavigationWrapper
  Future<void> refreshData() async {
    debugPrint('🏠 HomePage: refreshData() called from external');
    if (!mounted) return;
    await _loadData();
    
    // ✅ CẬP NHẬT WIDGET
    try {
      await WidgetService.updateWidgetData();
    } catch (e) {
      debugPrint('❌ Error updating widget: $e');
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get current user ID from SharedPreferences and load user data
      final currentUserId = await _userRepository.getCurrentUserId();
      final currentUser = await _userRepository.getUserById(currentUserId);

      if (currentUser != null) {
        _currentUser = currentUser;
      } else {
        // If user not found, get the first available user (fallback)
        final users = await _userRepository.getAllUsers();
        if (users.isNotEmpty) {
          _currentUser = users.first;
        }
      }

      // Load recent transactions
      _recentTransactions = await _transactionRepository.getRecentTransactions(limit: 10);

      // Load categories mapping
      final categories = await _categoryRepository.getAllCategories();
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
      final budgetProgress = await _budgetRepository.getOverallBudgetProgress();

      // Lấy danh sách ngân sách theo danh mục
      final categoryBudgets = await _budgetRepository.getBudgetProgress();

      // Lọc bỏ các budget đã hết hạn (chỉ hiển thị budget active ở home page)
      final activeBudgetProgress = budgetProgress != null &&
                                    (budgetProgress['isExpired'] == false || budgetProgress['isExpired'] == null)
          ? budgetProgress
          : null;

      final activeCategoryBudgets = categoryBudgets
          .where((budget) => budget['isExpired'] == false || budget['isExpired'] == null)
          .toList();

      setState(() {
        _overallBudgetProgress = activeBudgetProgress;
        _categoryBudgets = activeCategoryBudgets;
        _hasCheckedBudget = true;
      });

      // Kiểm tra và hiển thị cảnh báo nếu vượt hạn mức (chỉ với budget active)
      if (activeBudgetProgress != null && activeBudgetProgress['isOverBudget'] == true) {
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
      final allTransactions = await _transactionRepository.getAllTransactions();

      _totalIncome = 0;
      _totalExpense = 0;
      _totalLent = 0;
      _totalBorrowed = 0;

      // Get time range based on filter
      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

      switch (_timeFilter) {
        case TimeFilter.week:
          // Tuần này: từ thứ 2 đến chủ nhật
          final weekday = now.weekday; // 1=Monday, 7=Sunday
          startDate = DateTime(now.year, now.month, now.day - (weekday - 1));
          endDate = DateTime(now.year, now.month, now.day + (7 - weekday), 23, 59, 59);
          break;
        case TimeFilter.month:
          // Tháng này: từ ngày 1 đến ngày cuối tháng
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59); // Ngày cuối tháng
          break;
        case TimeFilter.year:
          // Năm này: từ 1/1 đến 31/12
          startDate = DateTime(now.year, 1, 1);
          endDate = DateTime(now.year, 12, 31, 23, 59, 59);
          break;
      }

      // Calculate income and expense from transactions with time filter
      for (final transaction in allTransactions) {
        // Only filter income and expense by time
        if (transaction.type == 'income' ||
            transaction.type == 'debt_collected' ||
            transaction.type == 'expense' ||
            transaction.type == 'debt_paid') {

          // Check if transaction is within time range
          final isInRange = transaction.date.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
                           transaction.date.isBefore(endDate.add(const Duration(seconds: 1)));

          if (isInRange) {
            switch (transaction.type) {
              case 'income':
                _totalIncome += transaction.amount;
                break;
              case 'expense':
                _totalExpense += transaction.amount;
                break;
            }
          }
        }
      }

      // Calculate loan statistics directly from loans table (không bị ảnh hưởng bởi filter)
      await _calculateLoanStats();
    } catch (e) {
      debugPrint('Error calculating overview stats: $e');
    }
  }

  /// Calculate loan statistics directly from loans table
  /// This includes both old debts (isOldDebt = 1) and new loans (isOldDebt = 0)
  /// Now accounts for partial payments using amountPaid field
  Future<void> _calculateLoanStats() async {
    try {
      final allLoans = await _loanRepository.getAllLoans();

      _totalLent = 0;
      _totalBorrowed = 0;

      for (final loan in allLoans) {
        // Only count active loans (not paid/completed)
        if (loan.status == 'active') {
          // Calculate remaining amount after partial payments
          final remainingAmount = loan.amount - loan.amountPaid;

          if (loan.loanType == 'lend') {
            _totalLent += remainingAmount;
          } else if (loan.loanType == 'borrow') {
            _totalBorrowed += remainingAmount;
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
      final currentUserId = await _userRepository.getCurrentUserId();

      // Lấy số dư hiện tại từ database (đã được cập nhật chính xác)
      final currentUser = await _userRepository.getUserById(currentUserId);
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

  /// Mở màn hình quét hóa đơn OCR
  Future<void> _openOcrScanner() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ReceiptScanScreen()),
    );

    // Nếu transaction được thêm thành công, refresh data
    if (result == true && mounted) {
      debugPrint('🔄 HomePage: Transaction added from Receipt Scan, refreshing data...');
      await _refreshHomeData();
    }
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotificationListScreen(),
      ),
    ).then((_) {
      // Cập nhật badge count khi quay lại
      if (mounted) {
        context.read<NotificationProvider>().updateBadgeCounts();
      }
    });
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
        onScanPressed: _openOcrScanner,
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
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100), // Thêm bottom padding để tránh navigation bar
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
                        timeFilter: _timeFilter,
                        onTimeFilterChanged: (newFilter) {
                          setState(() {
                            _timeFilter = newFilter;
                          });
                          _calculateOverviewStats().then((_) {
                            if (mounted) {
                              setState(() {});
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 24),

                      // Hiển thị tất cả ngân sách đang hoạt động (luôn hiển thị)
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
                        child: Consumer<CurrencyProvider>(
                          builder: (context, currencyProvider, child) {
                            return AllBudgetsWidget(
                              overallBudget: _overallBudgetProgress,
                              categoryBudgets: _categoryBudgets,
                              onRefresh: () async {
                                await _refreshHomeData();
                              },
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 24),

                      QuickActions(
                        onIncomePressed: () => _navigateToAddTransaction('income'),
                        onExpensePressed: () => _navigateToAddTransaction('expense'),
                        onLoanGivenPressed: () => _navigateToAddTransaction('loan_given'),
                        onLoanReceivedPressed: () => _navigateToAddTransaction('loan_received'),
                        onTransactionAdded: _loadData, // Refresh data after adding transaction
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
