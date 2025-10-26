import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/transaction.dart' as transaction_model;
import '../../models/category.dart';
import '../../utils/currency_formatter.dart';
import '../home/home_colors.dart';
import '../home/home_icons.dart';
import 'edit_transaction_screen.dart';
import 'transaction_detail_screen.dart';
import '../main_navigation_wrapper.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

enum TimeFilter { week, month, year }
enum TypeFilter { all, income, expense }

class _TransactionsScreenState extends State<TransactionsScreen> with WidgetsBindingObserver {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  List<transaction_model.Transaction> _transactions = [];
  List<transaction_model.Transaction> _selectedTransactions = [];
  Map<int, Category> _categoriesMap = {};
  TimeFilter _timeFilter = TimeFilter.week;
  TypeFilter _typeFilter = TypeFilter.all;
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
    final categories = await _databaseHelper.getAllCategories();
    setState(() {
      _categoriesMap = {for (var category in categories) category.id!: category};
    });
  }

  Future<void> _fetchTransactions() async {
    setState(() => _isLoading = true);
    DateTime now = DateTime.now();
    DateTime start;

    switch (_timeFilter) {
      case TimeFilter.week:
        start = now.subtract(Duration(days: now.weekday - 1));
        break;
      case TimeFilter.month:
        start = DateTime(now.year, now.month, 1);
        break;
      case TimeFilter.year:
        start = DateTime(now.year, 1, 1);
        break;
    }

    List<transaction_model.Transaction> all = await _databaseHelper.getAllTransactions();
    _transactions = all.where((t) =>
      (t.type == 'income' || t.type == 'expense' || t.type == 'loan_given' || t.type == 'loan_received') &&
      t.date.isAfter(start.subtract(const Duration(days: 1))) &&
      t.date.isBefore(now.add(const Duration(days: 1)))
    ).toList();

    // Apply type filter
    switch (_typeFilter) {
      case TypeFilter.income:
        _transactions = _transactions.where((t) => t.type == 'income').toList();
        break;
      case TypeFilter.expense:
        _transactions = _transactions.where((t) => t.type == 'expense').toList();
        break;
      case TypeFilter.all:
        // Show all transactions - no additional filtering needed
        break;
    }

    // Sort by date, newest first
    _transactions.sort((a, b) => b.date.compareTo(a.date));

    setState(() => _isLoading = false);
  }

  double get _totalIncome => _transactions.where((t) => t.type == 'income').fold(0, (sum, t) => sum + t.amount);
  double get _totalExpense => _transactions.where((t) => t.type == 'expense').fold(0, (sum, t) => sum + t.amount);

  void _onTimeFilterChanged(TimeFilter filter) {
    setState(() => _timeFilter = filter);
    _fetchTransactions();
  }

  void _onTypeFilterChanged(TypeFilter filter) {
    setState(() => _typeFilter = filter);
    _fetchTransactions();
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
      final currentUserId = await _databaseHelper.getCurrentUserId();
      final currentUser = await _databaseHelper.getUserById(currentUserId);

      if (currentUser == null) return;

      double balanceChange = 0;

      // Tính toán thay đổi số dư cho từng giao dịch bị xóa
      for (final transaction in deletedTransactions) {
        switch (transaction.type) {
          case 'income':
          case 'debt_collected':
            // Xóa thu nhập -> trừ khỏi số dư
            balanceChange -= transaction.amount;
            debugPrint('Deleted income ${transaction.amount} -> balance change: -${transaction.amount}');
            break;
          case 'expense':
          case 'debt_paid':
            // Xóa chi tiêu -> cộng lại vào số dư (vì khi tạo đã bị trừ)
            balanceChange += transaction.amount;
            debugPrint('Deleted expense ${transaction.amount} -> balance change: +${transaction.amount}');
            break;
          case 'loan_given':
            // Xóa giao dịch cho vay -> cộng lại vào số dư (vì khi tạo đã bị trừ)
            balanceChange += transaction.amount;
            debugPrint('Deleted loan_given ${transaction.amount} -> balance change: +${transaction.amount}');
            break;
          case 'loan_received':
            // Xóa giao dịch đi vay -> trừ khỏi số dư (vì khi tạo đã được cộng)
            balanceChange -= transaction.amount;
            debugPrint('Deleted loan_received ${transaction.amount} -> balance change: -${transaction.amount}');
            break;
          default:
            debugPrint('Unknown transaction type: ${transaction.type} - no balance change');
            break;
        }
      }

      // Cập nhật số dư mới
      final newBalance = currentUser.balance + balanceChange;
      final updatedUser = currentUser.copyWith(balance: newBalance);

      await _databaseHelper.updateUser(updatedUser);

      debugPrint('Updated user balance from ${currentUser.balance} to $newBalance (total change: $balanceChange)');
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
          await _databaseHelper.deleteTransaction(transaction.id!);
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

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Đã xóa giao dịch thành công!',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              backgroundColor: HomeColors.income,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
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
    }
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
      case 'income':
        return HomeColors.income;
      case 'expense':
        return HomeColors.expense;
      case 'loan_given':
        return HomeColors.expense;
      case 'loan_received':
        return HomeColors.income;
      default:
        return Colors.grey;
    }
  }

  String _getTransactionAmountDisplay(transaction_model.Transaction transaction) {
    String sign = transaction.type == 'income' || transaction.type == 'loan_received' ? '+' : '-';
    return '$sign${CurrencyFormatter.formatVND(transaction.amount.abs())}';
  }

  String _getTypeFilterDisplayText() {
    switch (_typeFilter) {
      case TypeFilter.all:
        return 'Tất cả giao dịch';
      case TypeFilter.income:
        return 'Thu nhập';
      case TypeFilter.expense:
        return 'Chi tiêu';
    }
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
                  ],
                ),
              ),
        backgroundColor: isDark
          ? const Color(0xFF2d3a4a) // Dark: Màu cá voi sát thủ
          : Theme.of(context).colorScheme.primary, // Light: Xanh biển
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter and Summary Section
          Container(
            decoration: BoxDecoration(
              color: isDark
                ? const Color(0xFF2d3a4a) // Dark: Màu cá voi sát thủ
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
                  // Time Filter
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildFilterButton('Tuần', TimeFilter.week),
                      const SizedBox(width: 8),
                      _buildFilterButton('Tháng', TimeFilter.month),
                      const SizedBox(width: 8),
                      _buildFilterButton('Năm', TimeFilter.year),
                    ],
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
                                Text(
                                  'Thu nhập',
                                  style: TextStyle(
                                    color: HomeColors.income,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  CurrencyFormatter.formatVND(_totalIncome),
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
                                Text(
                                  'Chi tiêu',
                                  style: TextStyle(
                                    color: HomeColors.expense,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  CurrencyFormatter.formatVND(_totalExpense),
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
                              'Số dư: ',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              CurrencyFormatter.formatVND(_totalIncome - _totalExpense),
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
                            padding: const EdgeInsets.all(16),
                            itemCount: _transactions.length,
                            itemBuilder: (ctx, i) {
                              final transaction = _transactions[i];
                              final category = transaction.categoryId != null
                                  ? _categoriesMap[transaction.categoryId!]
                                  : null;
                              final isSelected = _selectedTransactions.contains(transaction);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Material(
                                  borderRadius: BorderRadius.circular(12),
                                  color: isSelected
                                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                                    : Theme.of(context).colorScheme.surface,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => _onTransactionTap(transaction),
                                    onLongPress: () => _onLongPress(transaction),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
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
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  category?.name ?? 'Khác',
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
                                              if (!_isMultiSelectMode) ...[
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

  Widget _buildFilterButton(String text, TimeFilter filter) {
    final isSelected = _timeFilter == filter;
    return GestureDetector(
      onTap: () => _onTimeFilterChanged(filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? HomeColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: HomeColors.primary,
            width: 1.5,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : HomeColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToTransactionDetail(transaction_model.Transaction transaction) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionDetailScreen(
          transaction: transaction,
          onEdit: () {
            Navigator.pop(context); // Close detail screen first
            _editTransaction(transaction); // Then open edit screen
          },
        ),
      ),
    );

    if (result == true) {
      await _fetchTransactions();
    }
  }
}
