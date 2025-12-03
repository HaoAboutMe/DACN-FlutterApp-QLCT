import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/repositories/repositories.dart';
import '../../models/transaction.dart' as transaction_model;
import '../../models/category.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/month_year_picker_dialog.dart';
import '../home/home_colors.dart';
import '../home/home_icons.dart';
import '../add_transaction/add_transaction_page.dart';
import 'edit_transaction_screen.dart';
import 'transaction_detail_screen.dart';
import '../main_navigation_wrapper.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

enum TypeFilter { all, income, expense,  loan_given, loan_received, debt_paid, debt_collected }

class _TransactionsScreenState extends State<TransactionsScreen> with WidgetsBindingObserver {
  final TransactionRepository _transactionRepository = TransactionRepository();
  final CategoryRepository _categoryRepository = CategoryRepository();
  final UserRepository _userRepository = UserRepository();

  List<transaction_model.Transaction> _transactions = [];
  List<transaction_model.Transaction> _selectedTransactions = [];
  Map<int, Category> _categoriesMap = {};
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  TypeFilter _typeFilter = TypeFilter.all;
  int? _selectedCategoryId; // null means "All categories"
  bool _isLoading = true;
  bool _isMultiSelectMode = false;

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

  /// Called when app lifecycle changes - reload when app becomes active
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  /// Public method to reload data - can be called from MainNavigationWrapper
  Future<void> _loadData() async {
    if (!mounted) return;
    await _loadCategories();
    await _fetchTransactions();
  }

  /// Public method for external calls from MainNavigationWrapper
  Future<void> loadData() async {
    debugPrint('💳 TransactionsScreen: loadData() called from external');
    if (!mounted) return;
    await _loadCategories();
    await _fetchTransactions();
  }

  Future<void> _loadCategories() async {
    final categories = await _categoryRepository.getAllCategories();
    setState(() {
      _categoriesMap = {for (var category in categories) category.id!: category};
    });
  }

  Future<void> _fetchTransactions() async {
    setState(() => _isLoading = true);

    // Calculate start and end of selected month
    final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final end = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1).subtract(const Duration(days: 1));

    List<transaction_model.Transaction> all = await _transactionRepository.getAllTransactions();
    _transactions = all.where((t) =>
    (t.type == 'income' || t.type == 'expense' || t.type == 'loan_given' || t.type == 'loan_received' || t.type == "debt_paid" || t.type == "debt_collected") &&
        t.date.isAfter(start.subtract(const Duration(days: 1))) &&
        t.date.isBefore(end.add(const Duration(days: 1)))
    ).toList();

    // Apply type filter
    switch (_typeFilter) {
      case TypeFilter.income:
        _transactions = _transactions.where((t) =>
          t.type == 'income').toList();
        break;

      case TypeFilter.expense:
        _transactions = _transactions.where((t) =>
          t.type == 'expense').toList();
        break;
      case TypeFilter.loan_given:
        _transactions = _transactions.where((t) => t.type == 'loan_given').toList();
        break;

      case TypeFilter.loan_received:
        _transactions =
            _transactions.where((t) => t.type == 'loan_received').toList();
        break;

      case TypeFilter.debt_paid:
        _transactions = _transactions.where((t) => t.type == 'debt_paid').toList();
        break;

      case TypeFilter.debt_collected:
        _transactions =
            _transactions.where((t) => t.type == 'debt_collected').toList();
        break;
      case TypeFilter.all:
      // Show all transactions - no additional filtering needed
        break;
    }

    // Apply category filter
    if (_selectedCategoryId != null) {
      _transactions = _transactions.where((t) => t.categoryId == _selectedCategoryId).toList();
    }

    // Sort by date, newest first
    _transactions.sort((a, b) => b.date.compareTo(a.date));

    setState(() => _isLoading = false);
  }

  double get _totalIncome => _transactions
      .where((t) =>
  t.type == 'income')
      .fold(0, (sum, t) => sum + t.amount);

  double get _totalExpense => _transactions
      .where((t) =>
  t.type == 'expense')
      .fold(0, (sum, t) => sum + t.amount);

  void _onTypeFilterChanged(TypeFilter filter) {
    setState(() => _typeFilter = filter);
    _fetchTransactions();
  }

  Future<void> _showCategoryFilterBottomSheet() async {
    final allCategories = _categoriesMap.values.toList();
    final incomeCategories = allCategories.where((c) => c.type == 'income').toList();
    final expenseCategories = allCategories.where((c) => c.type == 'expense').toList();

    incomeCategories.sort((a, b) => a.name.compareTo(b.name));
    expenseCategories.sort((a, b) => a.name.compareTo(b.name));

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Lọc theo danh mục',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (_selectedCategoryId != null)
                    TextButton(
                      onPressed: () {
                        setState(() => _selectedCategoryId = null);
                        _fetchTransactions();
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Xóa bộ lọc',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            Divider(height: 1, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.2)),

            // "All categories" option
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: InkWell(
                onTap: () {
                  setState(() => _selectedCategoryId = null);
                  _fetchTransactions();
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _selectedCategoryId == null
                        ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                        : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: _selectedCategoryId == null
                        ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.category,
                          color: Theme.of(context).colorScheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tất cả danh mục',
                          style: TextStyle(
                            fontWeight: _selectedCategoryId == null ? FontWeight.bold : FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (_selectedCategoryId == null)
                        Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                    ],
                  ),
                ),
              ),
            ),

            Divider(height: 1, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.2)),

            // Two column layout for categories
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Income categories column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Income header
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: HomeColors.income.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_upward, color: HomeColors.income, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  'Thu nhập',
                                  style: TextStyle(
                                    color: HomeColors.income,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Income categories list
                          ...incomeCategories.map((category) {
                            final isSelected = _selectedCategoryId == category.id;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                onTap: () {
                                  setState(() => _selectedCategoryId = category.id);
                                  _fetchTransactions();
                                  Navigator.pop(context);
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? HomeColors.income.withValues(alpha: 0.15)
                                        : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(10),
                                    border: isSelected
                                        ? Border.all(color: HomeColors.income, width: 2)
                                        : null,
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: HomeColors.getTransactionIconBackground(HomeColors.income),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              HomeIcons.getIconFromString(category.icon),
                                              color: HomeColors.income,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              category.name,
                                              style: TextStyle(
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                color: Theme.of(context).colorScheme.onSurface,
                                                fontSize: 13,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isSelected)
                                            Icon(Icons.check_circle, color: HomeColors.income, size: 18),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Expense categories column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Expense header
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: HomeColors.expense.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_downward, color: HomeColors.expense, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  'Chi tiêu',
                                  style: TextStyle(
                                    color: HomeColors.expense,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Expense categories list
                          ...expenseCategories.map((category) {
                            final isSelected = _selectedCategoryId == category.id;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                onTap: () {
                                  setState(() => _selectedCategoryId = category.id);
                                  _fetchTransactions();
                                  Navigator.pop(context);
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? HomeColors.expense.withValues(alpha: 0.15)
                                        : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(10),
                                    border: isSelected
                                        ? Border.all(color: HomeColors.expense, width: 2)
                                        : null,
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: HomeColors.getTransactionIconBackground(HomeColors.expense),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              HomeIcons.getIconFromString(category.icon),
                                              color: HomeColors.expense,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              category.name,
                                              style: TextStyle(
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                color: Theme.of(context).colorScheme.onSurface,
                                                fontSize: 13,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isSelected)
                                            Icon(Icons.check_circle, color: HomeColors.expense, size: 18),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onPreviousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
    _fetchTransactions();
  }

  void _onNextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    });
    _fetchTransactions();
  }

  Future<void> _onSelectMonthYear() async {
    final pickedDate = await showMonthYearPicker(
      context: context,
      initialDate: _selectedMonth,
    );

    if (pickedDate != null) {
      setState(() {
        _selectedMonth = pickedDate;
      });
      _fetchTransactions();
    }
  }

  void _onLongPress(transaction_model.Transaction transaction) {
    setState(() {
      _isMultiSelectMode = true;
      if (!_selectedTransactions.contains(transaction)) {
        _selectedTransactions.add(transaction);
      }
    });
  }

  void _onTransactionTap(transaction_model.Transaction transaction) {
    if (_isMultiSelectMode) {
      setState(() {
        if (_selectedTransactions.contains(transaction)) {
          _selectedTransactions.remove(transaction);
          if (_selectedTransactions.isEmpty) {
            _isMultiSelectMode = false;
          }
        } else {
          _selectedTransactions.add(transaction);
        }
      });
    } else {
      // Navigate to detail screen instead of edit
      _navigateToTransactionDetail(transaction);
    }
  }

  void _exitMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = false;
      _selectedTransactions.clear();
    });
  }

  /// Cập nhật số dư user sau khi xóa giao dịch
  Future<void> _updateUserBalanceAfterDelete(List<transaction_model.Transaction> deletedTransactions) async {
    try {
      // Lấy thông tin user hiện tại
      final currentUserId = await _userRepository.getCurrentUserId();
      final currentUser = await _userRepository.getUserById(currentUserId);

      if (currentUser == null) return;

      double balanceChange = 0;

      // Tính toán thay đổi số dư cho từng giao dịch bị xóa
      for (final transaction in deletedTransactions) {
        // ⚠️ QUAN TRỌNG: Bỏ qua Transaction liên quan đến Loan
        // Lý do: Số dư sẽ được xử lý khi xóa Loan, tránh cộng 2 lần
        if (transaction.loanId != null) {
          debugPrint('⚠️ Transaction ${transaction.description} liên quan đến Loan - BỎ QUA cập nhật số dư');
          continue;
        }

        // CHỈ xử lý Transaction KHÔNG liên quan đến Loan
        switch (transaction.type) {
          case 'income':
            // Xóa thu nhập -> trừ khỏi số dư
            balanceChange -= transaction.amount;
            debugPrint('Deleted income ${transaction.amount} -> balance change: -${transaction.amount}');
            break;
          case 'expense':
            // Xóa chi tiêu -> cộng lại vào số dư (vì khi tạo đã bị trừ)
            balanceChange += transaction.amount;
            debugPrint('Deleted expense ${transaction.amount} -> balance change: +${transaction.amount}');
            break;
          case 'debt_collected':
          case 'debt_paid':
          case 'loan_given':
          case 'loan_received':
            // ⚠️ Các loại này KHÔNG NÊN xảy ra vì đã check loanId ở trên
            // Nhưng để an toàn, log warning và bỏ qua
            debugPrint('⚠️ WARNING: Transaction type ${transaction.type} không nên xảy ra khi loanId = null');
            break;
          default:
            debugPrint('Unknown transaction type: ${transaction.type} - no balance change');
            break;
        }
      }

      // Chỉ cập nhật số dư nếu có thay đổi
      if (balanceChange != 0) {
        final newBalance = currentUser.balance + balanceChange;
        final updatedUser = currentUser.copyWith(balance: newBalance);
        await _userRepository.updateUser(updatedUser);
        debugPrint('✅ Updated user balance from ${currentUser.balance} to $newBalance (total change: $balanceChange)');
      } else {
        debugPrint('✅ No balance change needed (all transactions were loan-related)');
      }
    } catch (e) {
      debugPrint('Error updating user balance after delete: $e');
    }
  }

  Future<void> _deleteSelectedTransactions() async {
    if (_selectedTransactions.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Xác nhận xóa',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Text(
          'Bạn có chắc muốn xóa ${_selectedTransactions.length} giao dịch này không?',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Hủy',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: HomeColors.expense,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Xóa', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        for (var transaction in _selectedTransactions) {
          await _transactionRepository.deleteTransaction(transaction.id!);
        }

        // Cập nhật số dư người dùng sau khi xóa giao dịch
        await _updateUserBalanceAfterDelete(_selectedTransactions);

        setState(() {
          _selectedTransactions.clear();
          _isMultiSelectMode = false;
        });

        await _fetchTransactions();

        // Trigger HomePage reload after deleting transactions that affect balance
        mainNavigationKey.currentState?.refreshHomePage();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Lỗi khi xóa: $e',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              backgroundColor: HomeColors.expense,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      }
    }
  }

  Future<void> _editTransaction(transaction_model.Transaction transaction) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditTransactionScreen(transaction: transaction),
      ),
    );

    if (result == true) {
      await _fetchTransactions();
      // Trigger HomePage reload to update balance
      mainNavigationKey.currentState?.refreshHomePage();
    }
  }

  Future<void> _navigateToAddTransaction() async {
    debugPrint('🚀 Navigating to AddTransactionPage...');

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddTransactionPage(),
      ),
    );

    debugPrint('🔄 Returned from AddTransactionPage with result: $result');

    // Always reload transactions when returning
    await _fetchTransactions();

    // Trigger HomePage reload to update balance
    mainNavigationKey.currentState?.refreshHomePage();
  }

  IconData _getTransactionIcon(transaction_model.Transaction transaction) {
    // Use category icon if available, otherwise use transaction type icon
    final category = transaction.categoryId != null ? _categoriesMap[transaction.categoryId!] : null;

    if (category != null) {
      return HomeIcons.getIconFromString(category.icon);
    } else {
      return HomeIcons.getTransactionTypeIcon(transaction.type);
    }
  }

  Color _getTransactionColor(String type) {
    switch (type) {
    // Thu nhập & các loại làm tăng số dư
      case 'income':
      case 'loan_received':
      case 'debt_collected': // Thu nợ
        return HomeColors.income;

    // Chi tiêu & các loại làm giảm số dư
      case 'expense':
      case 'loan_given':
      case 'debt_paid': // Trả nợ
        return HomeColors.expense;

      default:
        return Colors.grey;
    }
  }

  String _getTransactionAmountDisplay(transaction_model.Transaction transaction) {
    String sign = transaction.type == 'income' || transaction.type == 'loan_received' || transaction.type == "debt_collected" ? '+' : '-';
    return '$sign${CurrencyFormatter.formatAmount(transaction.amount.abs())}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: _isMultiSelectMode
            ? Text(
          '${_selectedTransactions.length} đã chọn',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        )
            : DropdownButtonHideUnderline(
          child: DropdownButton<TypeFilter>(
            value: _typeFilter,
            icon: Icon(
              Icons.keyboard_arrow_down,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
            dropdownColor: isDark
                ? const Color(0xFF2d3a4a)
                : Theme.of(context).colorScheme.primary,
            onChanged: (TypeFilter? newValue) {
              if (newValue != null) {
                _onTypeFilterChanged(newValue);
              }
            },
            items: [
              DropdownMenuItem<TypeFilter>(
                value: TypeFilter.all,
                child: Text(
                  'Tất cả giao dịch',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              DropdownMenuItem<TypeFilter>(
                value: TypeFilter.income,
                child: Text(
                  'Thu nhập',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              DropdownMenuItem<TypeFilter>(
                value: TypeFilter.expense,
                child: Text(
                  'Chi tiêu',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              DropdownMenuItem<TypeFilter>(
                value: TypeFilter.loan_given,
                child: Text(
                  'Cho vay',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              DropdownMenuItem<TypeFilter>(
                value: TypeFilter.loan_received,
                child: Text(
                  'Đi vay',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              DropdownMenuItem<TypeFilter>(
                value: TypeFilter.debt_paid,
                child: Text(
                  'Trả nợ',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              DropdownMenuItem<TypeFilter>(
                value: TypeFilter.debt_collected,
                child: Text(
                  'Thu nợ',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: isDark
            ? Theme.of(context).scaffoldBackgroundColor // Dark: Màu cá voi sát thủ
            : Theme.of(context).colorScheme.primary, // Light: Xanh biển
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        // Chỉ hiện leading khi ở chế độ multi-select
        automaticallyImplyLeading: false,
        leading: _isMultiSelectMode
            ? IconButton(
          icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onPrimary),
          onPressed: _exitMultiSelectMode,
        )
            : null, // Loại bỏ nút back vì đây là tab chính
        actions: [
          if (_isMultiSelectMode && _selectedTransactions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: _deleteSelectedTransactions,
              tooltip: 'Xóa giao dịch đã chọn',
            )
          else ...[
            // Filter by category button with badge indicator
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.filter_list, color: Colors.white),
                  onPressed: _showCategoryFilterBottomSheet,
                  tooltip: 'Lọc theo danh mục',
                ),
                if (_selectedCategoryId != null)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: HomeColors.expense,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: _navigateToAddTransaction,
              tooltip: 'Thêm giao dịch mới',
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Filter and Summary Section
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Theme.of(context).scaffoldBackgroundColor // Dark: Màu cá voi sát thủ
                  : Theme.of(context).colorScheme.primary, // Light: Xanh biển
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.black.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Monthly Navigation
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Previous Month Button
                        InkWell(
                          onTap: _onPreviousMonth,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.chevron_left,
                              color: Theme.of(context).colorScheme.primary,
                              size: 24,
                            ),
                          ),
                        ),

                        // Month Year Display - Tappable
                        Expanded(
                          child: InkWell(
                            onTap: _onSelectMonthYear,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                              child: Text(
                                DateFormat('MMMM, yyyy', 'vi_VN').format(_selectedMonth)
                                    .replaceFirst(RegExp(r'tháng '), 'Tháng '),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Next Month Button
                        InkWell(
                          onTap: _onNextMonth,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.chevron_right,
                              color: Theme.of(context).colorScheme.primary,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Income/Expense Summary
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Thu nhập',
                                      style: TextStyle(
                                        color: HomeColors.income,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            backgroundColor: Theme.of(context).colorScheme.surface,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            title: Row(
                                              children: [
                                                Icon(
                                                  Icons.info_outline,
                                                  color: HomeColors.income,
                                                  size: 24,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Thông tin',
                                                  style: TextStyle(
                                                    color: Theme.of(context).colorScheme.onSurface,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            content: Text(
                                              'Các giao dịch đi vay, thu nợ không được tính là thu nhập.',
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                fontSize: 16,
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx),
                                                child: Text(
                                                  'Đã hiểu',
                                                  style: TextStyle(
                                                    color: Theme.of(context).colorScheme.primary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      child: Icon(
                                        Icons.info_outline,
                                        color: HomeColors.income.withValues(alpha: 0.7),
                                        size: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  CurrencyFormatter.formatAmount(_totalIncome),
                                  style: TextStyle(
                                    color: HomeColors.income,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            backgroundColor: Theme.of(context).colorScheme.surface,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            title: Row(
                                              children: [
                                                Icon(
                                                  Icons.info_outline,
                                                  color: HomeColors.expense,
                                                  size: 24,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Thông tin',
                                                  style: TextStyle(
                                                    color: Theme.of(context).colorScheme.onSurface,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            content: Text(
                                              'Các giao dịch cho vay, trả nợ không được tính là chi tiêu.',
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                fontSize: 16,
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx),
                                                child: Text(
                                                  'Đã hiểu',
                                                  style: TextStyle(
                                                    color: Theme.of(context).colorScheme.primary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      child: Icon(
                                        Icons.info_outline,
                                        color: HomeColors.expense.withValues(alpha: 0.7),
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Chi tiêu',
                                      style: TextStyle(
                                        color: HomeColors.expense,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  CurrencyFormatter.formatAmount(_totalExpense),
                                  style: TextStyle(
                                    color: HomeColors.expense,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Divider(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Chênh lệch: ',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              CurrencyFormatter.formatAmount(_totalIncome - _totalExpense),
                              style: TextStyle(
                                color: (_totalIncome - _totalExpense) >= 0
                                    ? HomeColors.income
                                    : HomeColors.expense,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Transactions List
          Expanded(
            child: _isLoading
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Đang tải giao dịch...',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadData,
              color: Theme.of(context).colorScheme.primary,
              backgroundColor: Theme.of(context).colorScheme.surface,
              child: _transactions.isEmpty
                  ? ListView(
                // Need ListView for RefreshIndicator to work on empty content
                children: [
                  Container(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Không có giao dịch nào',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'trong khoảng thời gian này',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '↓ Kéo xuống để làm mới',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
                  : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // Thêm bottom padding để tránh navigation bar
                itemCount: _transactions.length,
                itemBuilder: (ctx, i) {
                  final transaction = _transactions[i];
                  final category = transaction.categoryId != null
                      ? _categoriesMap[transaction.categoryId!]
                      : null;
                  final isSelected = _selectedTransactions.contains(transaction);
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  final containerColor = isDark
                      ? Theme.of(context).colorScheme.surface
                      : Colors.white;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      borderRadius: BorderRadius.circular(12),
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                          : containerColor,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _onTransactionTap(transaction),
                        onLongPress: () => _onLongPress(transaction),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected ? null : containerColor,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                                : null,
                            boxShadow: !isSelected ? [
                              BoxShadow(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.black.withValues(alpha: 0.3)
                                    : Colors.black.withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ] : null,
                          ),
                          child: Row(
                            children: [
                              // Selection/Icon
                              if (_isMultiSelectMode)
                                Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  child: Icon(
                                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                    color: isSelected ? HomeColors.primary : Colors.grey,
                                    size: 24,
                                  ),
                                )
                              else
                                Container(
                                  width: 48,
                                  height: 48,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: HomeColors.getTransactionIconBackground(
                                        _getTransactionColor(transaction.type)
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _getTransactionIcon(transaction),
                                    color: _getTransactionColor(transaction.type),
                                    size: 24,
                                  ),
                                ),

                              // Transaction Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      transaction.description,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _getCategoryDisplayName(transaction, category),
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${transaction.date.day}/${transaction.date.month}/${transaction.date.year}',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Amount and Edit Button
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _getTransactionAmountDisplay(transaction),
                                    style: TextStyle(
                                      color: _getTransactionColor(transaction.type),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (!_isMultiSelectMode && transaction.loanId == null) ...[
                                    const SizedBox(height: 8),
                                    GestureDetector(
                                      onTap: () => _editTransaction(transaction),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.edit,
                                          color: Theme.of(context).colorScheme.primary,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (!_isMultiSelectMode && transaction.loanId != null) ...[
                                    const SizedBox(height: 8),
                                    Tooltip(
                                      message: 'Không thể chỉnh sửa giao dịch liên kết với khoản vay',
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.lock,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _navigateToTransactionDetail(transaction_model.Transaction transaction) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionDetailScreen(
          transaction: transaction,
          onEdit: () async {
            final result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => EditTransactionScreen(transaction: transaction),
              ),
            );

            if (result == true && context.mounted) {
              setState(() {});
            }
          },
        ),
      ),
    );

    if (result == true) {
      await _fetchTransactions();
    }
  }

  String _getCategoryDisplayName(transaction_model.Transaction transaction, Category? category) {
    // Nếu transaction có categoryId và category hợp lệ -> dùng tên category
    if (category != null) {
      return category.name;
    }

    // Nếu không có category -> dựa theo type
    switch (transaction.type) {
      case 'loan_given':
        return 'Cho vay';
      case 'loan_received':
        return 'Đi vay';
      case 'debt_paid':
        return 'Trả nợ';
      case 'debt_collected':
        return 'Thu nợ';
      case 'income':
        return 'Thu nhập';
      case 'expense':
        return 'Chi tiêu';
      default:
        return 'Khác';
    }
  }

}