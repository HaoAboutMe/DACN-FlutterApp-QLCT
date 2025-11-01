import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/loan.dart';
import '../../models/transaction.dart' as transaction_model;
import '../../utils/currency_formatter.dart';
import '../home/home_colors.dart';
import '../add_loan/add_loan_page.dart';
import 'loan_detail_screen.dart';
import 'edit_loan_screen.dart';
import '../main_navigation_wrapper.dart';

enum LoanTypeFilter { all, lendNew, lendOld, borrowNew, borrowOld }

class LoanListScreen extends StatefulWidget {
  const LoanListScreen({super.key});

  @override
  State<LoanListScreen> createState() => _LoanListScreenState();
}

class _LoanListScreenState extends State<LoanListScreen> with WidgetsBindingObserver {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  List<Loan> _loans = [];
  List<Loan> _filteredLoans = [];
  List<int> _selectedIds = [];
  bool _isLoading = true;
  String _currentFilter = 'Tất cả'; // Tất cả, Tuần, Tháng, Năm, Sắp hết hạn
  LoanTypeFilter _loanTypeFilter = LoanTypeFilter.all;
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLoans();
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
      _loadLoans();
    }
  }

  /// Public method to reload data - can be called from MainNavigationWrapper
  Future<void> _loadLoans() async {
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
      });

      final loans = await _databaseHelper.getAllLoans();

      if (!mounted) return;

      setState(() {
        _loans = loans;
        _applyFilter();
        _isLoading = false;
      });

      debugPrint('Loaded ${_loans.length} loans successfully');
    } catch (e) {
      debugPrint('Error loading loans: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Public method for external calls from MainNavigationWrapper
  Future<void> loadLoans() async {
    debugPrint('💰 LoanListScreen: loadLoans() called from external');
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
      });

      final loans = await _databaseHelper.getAllLoans();

      if (!mounted) return;

      setState(() {
        _loans = loans;
        _applyFilter();
        _isLoading = false;
      });

      debugPrint('Loaded ${_loans.length} loans successfully');
    } catch (e) {
      debugPrint('Error loading loans: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilter() {
    final now = DateTime.now();
    setState(() {
      // First, filter by time
      switch (_currentFilter) {
        case 'Tuần':
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          final weekEnd = weekStart.add(const Duration(days: 6));
          _filteredLoans = _loans.where((loan) =>
            loan.loanDate.isAfter(weekStart.subtract(const Duration(days: 1))) &&
            loan.loanDate.isBefore(weekEnd.add(const Duration(days: 1)))
          ).toList();
          break;
        case 'Tháng':
          _filteredLoans = _loans.where((loan) =>
            loan.loanDate.month == now.month && loan.loanDate.year == now.year
          ).toList();
          break;
        case 'Năm':
          _filteredLoans = _loans.where((loan) =>
            loan.loanDate.year == now.year
          ).toList();
          break;
        case 'Sắp hết hạn':
          _filteredLoans = _loans.where((loan) =>
            loan.dueDate != null &&
            loan.dueDate!.isAfter(now) &&
            loan.dueDate!.difference(now).inDays <= 7
          ).toList();
          break;
        default: // Tất cả
          _filteredLoans = List.from(_loans);
      }

      // Then, filter by loan type (lend/borrow) and new/old
      switch (_loanTypeFilter) {
        case LoanTypeFilter.lendNew:
          _filteredLoans = _filteredLoans.where((loan) =>
            loan.loanType == 'lend' && loan.isOldDebt == 0
          ).toList();
          break;
        case LoanTypeFilter.lendOld:
          _filteredLoans = _filteredLoans.where((loan) =>
            loan.loanType == 'lend' && loan.isOldDebt == 1
          ).toList();
          break;
        case LoanTypeFilter.borrowNew:
          _filteredLoans = _filteredLoans.where((loan) =>
            loan.loanType == 'borrow' && loan.isOldDebt == 0
          ).toList();
          break;
        case LoanTypeFilter.borrowOld:
          _filteredLoans = _filteredLoans.where((loan) =>
            loan.loanType == 'borrow' && loan.isOldDebt == 1
          ).toList();
          break;
        case LoanTypeFilter.all:
          // No additional filtering
          break;
      }

      // Sort by date, newest first
      _filteredLoans.sort((a, b) => b.loanDate.compareTo(a.loanDate));
    });
  }

  void _onLoanTypeFilterChanged(LoanTypeFilter filter) {
    setState(() {
      _loanTypeFilter = filter;
      _applyFilter();
    });
  }

  void _onSelect(int id, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(id);
        if (!_isSelectionMode) _isSelectionMode = true;
      } else {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      }
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) _selectedIds.clear();
    });
  }

  Future<void> _deleteSelected() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final count = _selectedIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Xác nhận xóa',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Text(
          'Bạn có chắc muốn xóa $count khoản vay/đi vay này không?\n\n⚠️ Lưu ý: Nếu là khoản vay MỚI, số dư của bạn sẽ được cập nhật.',
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Hủy',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF44336), // Red for delete
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
        debugPrint('🗑️ Deleting $count loans...');

        // Delete each selected loan
        for (int id in _selectedIds) {
          await _databaseHelper.deleteLoan(id);
        }

        debugPrint('✅ Successfully deleted $count loans');

        // ✅ REALTIME: Reload loan list immediately after deletion
        await _loadLoans();

        // Clear selection state
        setState(() {
          _selectedIds.clear();
          _isSelectionMode = false;
        });

        // ✅ REALTIME: CRITICAL - Trigger HomePage reload to update balance immediately
        debugPrint('🔄 Triggering HomePage reload to update balance...');
        mainNavigationKey.currentState?.refreshHomePage();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '✅ Đã xóa $count khoản vay thành công!\n💰 Số dư HomePage đã cập nhật realtime.',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: HomeColors.income,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              duration: const Duration(seconds: 4),
            ),
          );
        }

        // ✅ REALTIME: Set flag to indicate data has changed
        debugPrint('🔄 LoanListScreen: Data changes completed, ready for realtime sync');

      } catch (e) {
        debugPrint('❌ Error deleting loans: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '❌ Lỗi khi xóa: $e',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: HomeColors.expense,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _navigateToAddLoan() async {
    debugPrint('🚀 Navigating to AddLoanPage...');

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddLoanPage(),
      ),
    );

    debugPrint('🔄 Returned from AddLoanPage with result: $result');

    // ✅ REALTIME: Always reload loans when returning
    await _loadLoans();

    // ✅ REALTIME: Trigger HomePage reload để cập nhật số dư
    mainNavigationKey.currentState?.refreshHomePage();

    // Show success message if loan was added
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              const Text(
                '✅ Loan đã được thêm! Số dư đã cập nhật.',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: HomeColors.income,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // ✅ REALTIME: Return true để trigger HomePage refresh khi quay về từ navigation
    // Điều này đảm bảo HomePage cập nhật số dư ngay khi user chuyển tab
    debugPrint('🔄 LoanListScreen: Notifying parent about data changes');
  }

  Future<void> _navigateToLoanDetail(Loan loan) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => LoanDetailScreen(loanId: loan.id!),
      ),
    );

    // Reload loans if any changes were made in detail screen
    if (result == true) {
      await _loadLoans();
      // Also trigger HomePage reload in case balance changed
      mainNavigationKey.currentState?.refreshHomePage();
    }
  }

  Future<void> _navigateToEditLoan(Loan loan) async {
    debugPrint('🚀 Navigating to EditLoanScreen for loan: ${loan.id}');

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditLoanScreen(loan: loan),
      ),
    );

    debugPrint('🔄 Returned from EditLoanScreen with result: $result');

    // ✅ REALTIME: Always reload loans when returning from edit
    if (result == true) {
      await _loadLoans();

      // ✅ REALTIME: Trigger HomePage reload to update balance
      mainNavigationKey.currentState?.refreshHomePage();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  '✅ Khoản vay đã được cập nhật!',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: HomeColors.income,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Color _getLoanColor(Loan loan) {
    if (loan.loanType == 'lend') {
      return HomeColors.loanGiven;
    } else {
      return HomeColors.loanReceived;
    }
  }

  Future<void> _markLoanAsPaid(Loan loan) async {
    if (loan.status == 'completed' || loan.status == 'paid') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⚠️ Khoản vay này đã được thanh toán rồi!'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    // Show confirmation dialog
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '💰 Xác nhận thanh toán',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loan.loanType == 'lend'
                  ? 'Xác nhận rằng ${loan.personName} đã trả nợ?'
                  : 'Xác nhận rằng bạn đã trả nợ cho ${loan.personName}?',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getLoanColor(loan).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.attach_money,
                    color: _getLoanColor(loan),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Số tiền: ${CurrencyFormatter.formatVND(loan.amount)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _getLoanColor(loan),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              loan.loanType == 'lend'
                  ? '✅ Số dư sẽ được cộng thêm ${CurrencyFormatter.formatVND(loan.amount)}'
                  : '⚠️ Số dư sẽ bị trừ ${CurrencyFormatter.formatVND(loan.amount)}',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Hủy',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50), // Green for success
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Xác nhận',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Card(
          color: colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  'Đang xử lý...',
                  style: TextStyle(color: colorScheme.onSurface),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Create payment transaction
      final transactionType = loan.loanType == 'lend' ? 'debt_collected' : 'debt_paid';
      final description = loan.loanType == 'lend'
          ? 'Thu hồi nợ từ ${loan.personName}'
          : 'Trả nợ cho ${loan.personName}';

      final paymentTransaction = transaction_model.Transaction(
        amount: loan.amount,
        description: description,
        date: DateTime.now(),
        categoryId: null,
        loanId: loan.id,
        type: transactionType,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Mark loan as paid
      await _databaseHelper.markLoanAsPaid(
        loanId: loan.id!,
        paymentTransaction: paymentTransaction,
      );

      debugPrint('✅ Loan ${loan.id} marked as paid successfully');

      // Reload loan list
      await _loadLoans();

      // Trigger HomePage reload
      mainNavigationKey.currentState?.refreshHomePage();

      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  loan.loanType == 'lend'
                      ? '✅ Đã thu hồi nợ từ ${loan.personName}!'
                      : '✅ Đã trả nợ cho ${loan.personName}!',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: HomeColors.income,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error marking loan as paid: $e');

      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('❌ Lỗi: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  IconData _getLoanIcon(Loan loan) {
    if (loan.loanType == 'lend') {
      return Icons.arrow_upward_rounded;
    } else {
      return Icons.arrow_downward_rounded;
    }
  }

  String _getLoanTypeText(Loan loan) {
    if (loan.loanType == 'lend') {
      return 'Cho vay';
    } else {
      return 'Đi vay';
    }
  }

  String _getStatusText(Loan loan) {
    // Kiểm tra trạng thái thanh toán trước
    if (loan.status == 'completed' || loan.status == 'paid') {
      return 'Đã thanh toán';
    }

    final now = DateTime.now();
    if (loan.dueDate == null) return 'Đang hoạt động';
    if (loan.dueDate!.isBefore(now)) return 'Quá hạn';
    if (loan.dueDate!.difference(now).inDays <= 7) return 'Sắp hết hạn';
    return 'Đang hoạt động';
  }

  Color _getStatusColor(Loan loan) {
    final status = _getStatusText(loan);
    if (status == 'Quá hạn') return Colors.red;
    if (status == 'Sắp hết hạn') return Colors.orange;
    if (status == 'Đã thanh toán') return HomeColors.income; // Màu xanh lá cho đã thanh toán
    return HomeColors.income;
  }

  String _getBadgeText(Loan loan) {
    return loan.isOldDebt == 0 ? 'MỚI' : 'CŨ';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalLend = _filteredLoans
        .where((l) => l.loanType == 'lend')
        .fold<double>(0, (sum, l) => sum + l.amount);

    final totalBorrow = _filteredLoans
        .where((l) => l.loanType == 'borrow')
        .fold<double>(0, (sum, l) => sum + l.amount);


    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: _isSelectionMode
            ? Text(
                '${_selectedIds.length} đã chọn',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              )
            : DropdownButtonHideUnderline(
                child: DropdownButton<LoanTypeFilter>(
                  value: _loanTypeFilter,
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
                  onChanged: (LoanTypeFilter? newValue) {
                    if (newValue != null) {
                      _onLoanTypeFilterChanged(newValue);
                    }
                  },
                  items: [
                    DropdownMenuItem<LoanTypeFilter>(
                      value: LoanTypeFilter.all,
                      child: Text(
                        'Tất cả khoản vay',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    DropdownMenuItem<LoanTypeFilter>(
                      value: LoanTypeFilter.lendNew,
                      child: Text(
                        'Cho vay mới',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    DropdownMenuItem<LoanTypeFilter>(
                      value: LoanTypeFilter.lendOld,
                      child: Text(
                        'Cho vay cũ',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    DropdownMenuItem<LoanTypeFilter>(
                      value: LoanTypeFilter.borrowNew,
                      child: Text(
                        'Đi vay mới',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    DropdownMenuItem<LoanTypeFilter>(
                      value: LoanTypeFilter.borrowOld,
                      child: Text(
                        'Đi vay cũ',
                        style: TextStyle(
                          color: Colors.white,
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
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _toggleSelectionMode,
              )
            : null,
        actions: [
          if (_isSelectionMode && _selectedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: _deleteSelected,
              tooltip: 'Xóa đã chọn',
            )
          else
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: _navigateToAddLoan,
              tooltip: 'Thêm khoản vay mới',
            ),
        ],
      ),
      body: Column(
        children: [
          // Summary Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
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
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    label: 'Tổng cho vay',
                    amount: totalLend,
                    color: HomeColors.loanGiven,
                    icon: Icons.arrow_upward_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    label: 'Tổng đi vay',
                    amount: totalBorrow,
                    color: HomeColors.loanReceived,
                    icon: Icons.arrow_downward_rounded,
                  ),
                ),
              ],
            ),
          ),

          // Filter Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).colorScheme.primary),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _currentFilter,
                        isExpanded: true,
                        icon: Icon(Icons.keyboard_arrow_down, color: Theme.of(context).colorScheme.primary),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _currentFilter = newValue;
                              _applyFilter();
                            });
                          }
                        },
                        items: <String>['Tất cả', 'Tuần', 'Tháng', 'Năm', 'Sắp hết hạn']
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _toggleSelectionMode,
                  icon: Icon(
                    _isSelectionMode ? Icons.close : Icons.checklist,
                    size: 18,
                  ),
                  label: Text(_isSelectionMode ? 'Hủy' : 'Chọn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSelectionMode
                        ? HomeColors.expense
                        : HomeColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Loans List
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(HomeColors.primary),
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Đang tải dữ liệu...',
                          style: TextStyle(
                            color: HomeColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadLoans,
                    color: HomeColors.primary,
                    backgroundColor: HomeColors.cardBackground,
                    child: _filteredLoans.isEmpty
                        ? ListView(
                            // Need ListView for RefreshIndicator to work on empty content
                            children: [
                              Container(
                                height: MediaQuery.of(context).size.height * 0.6,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.account_balance_wallet_outlined,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Không có khoản vay nào',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Nhấn nút + để thêm khoản vay mới',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      '↓ Kéo xuống để làm mới',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: HomeColors.primary,
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
                            itemCount: _filteredLoans.length,
                            itemBuilder: (context, index) {
                              final loan = _filteredLoans[index];
                              final isSelected = _selectedIds.contains(loan.id);
                              final loanColor = _getLoanColor(loan);
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
                                    onTap: () {
                                      if (_isSelectionMode) {
                                        _onSelect(loan.id!, !isSelected);
                                      } else {
                                        _navigateToLoanDetail(loan);
                                      }
                                    },
                                    onLongPress: () {
                                      _onSelect(loan.id!, true);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: isSelected ? null : containerColor,
                                        borderRadius: BorderRadius.circular(12),
                                        border: isSelected
                                            ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                                            : null,
                                        boxShadow: !isSelected
                                            ? [
                                                BoxShadow(
                                                  color: Theme.of(context).brightness == Brightness.dark
                                                    ? Colors.black.withValues(alpha: 0.3)
                                                    : Colors.black.withValues(alpha: 0.08),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Row(
                                        children: [
                                          // Selection checkbox or icon
                                          if (_isSelectionMode)
                                            Container(
                                              margin: const EdgeInsets.only(right: 12),
                                              child: Icon(
                                                isSelected
                                                    ? Icons.check_circle
                                                    : Icons.radio_button_unchecked,
                                                color: isSelected
                                                    ? HomeColors.primary
                                                    : Colors.grey,
                                                size: 24,
                                              ),
                                            )
                                          else
                                            Container(
                                              width: 48,
                                              height: 48,
                                              margin: const EdgeInsets.only(right: 12),
                                              decoration: BoxDecoration(
                                                color: loanColor.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Icon(
                                                _getLoanIcon(loan),
                                                color: loanColor,
                                                size: 24,
                                              ),
                                            ),

                                          // Loan details
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        loan.personName,
                                                        style: TextStyle(
                                                          color: Theme.of(context).colorScheme.onSurface,
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: loan.isOldDebt == 0
                                                            ? HomeColors.primary.withValues(alpha: 0.1)
                                                            : Colors.grey.withValues(alpha: 0.2),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Text(
                                                        _getBadgeText(loan),
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: loan.isOldDebt == 0
                                                              ? HomeColors.primary
                                                              : Colors.grey[700],
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _getLoanTypeText(loan),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: loanColor,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.calendar_today,
                                                      size: 12,
                                                      color: HomeColors.textSecondary,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${loan.loanDate.day}/${loan.loanDate.month}/${loan.loanDate.year}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: HomeColors.textSecondary,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: _getStatusColor(loan).withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        _getStatusText(loan),
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: _getStatusColor(loan),
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Amount and Edit button
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                CurrencyFormatter.formatVND(loan.amount),
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: loanColor,
                                                ),
                                              ),
                                              if (loan.dueDate != null) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Hạn: ${loan.dueDate!.day}/${loan.dueDate!.month}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: HomeColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                              if (!_isSelectionMode) ...[
                                                const SizedBox(height: 8),
                                                // Mark as Paid button (only show if not paid)
                                                if (loan.status != 'completed' && loan.status != 'paid')
                                                  InkWell(
                                                    onTap: () => _markLoanAsPaid(loan),
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: HomeColors.income.withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Icons.check_circle,
                                                            size: 14,
                                                            color: HomeColors.income,
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            loan.loanType == 'lend' ? 'Thu nợ' : 'Trả nợ',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: HomeColors.income,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                if (loan.status != 'completed' && loan.status != 'paid')
                                                  const SizedBox(height: 4),
                                                // Edit button
                                                InkWell(
                                                  onTap: () => _navigateToEditLoan(loan),
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: HomeColors.primary.withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.edit,
                                                          size: 14,
                                                          color: HomeColors.primary,
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          'Sửa',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: HomeColors.primary,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
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
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: _navigateToAddLoan,
              backgroundColor: HomeColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            ),
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerColor = isDark
        ? Theme.of(context).colorScheme.surface
        : Colors.white;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark
              ? Colors.black.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.08),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.formatVND(amount),
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
