import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/loan.dart';
import '../../utils/currency_formatter.dart';
import '../home/home_colors.dart';
import '../add_loan/add_loan_page.dart';
import 'loan_detail_screen.dart';

class LoanListScreen extends StatefulWidget {
  const LoanListScreen({super.key});

  @override
  State<LoanListScreen> createState() => _LoanListScreenState();
}

class _LoanListScreenState extends State<LoanListScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  List<Loan> _loans = [];
  List<Loan> _filteredLoans = [];
  List<int> _selectedIds = [];
  bool _isLoading = true;
  String _currentFilter = 'Tất cả'; // Tất cả, Tuần, Tháng, Năm, Sắp hết hạn
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadLoans();
  }

  Future<void> _loadLoans() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final loans = await _databaseHelper.getAllLoans();

      setState(() {
        _loans = loans;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading loans: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilter() {
    final now = DateTime.now();
    setState(() {
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
      // Sort by date, newest first
      _filteredLoans.sort((a, b) => b.loanDate.compareTo(a.loanDate));
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
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HomeColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Xác nhận xóa',
          style: TextStyle(
            color: HomeColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Text(
          'Bạn có chắc muốn xóa $count khoản vay/đi vay này không?',
          style: TextStyle(
            color: HomeColors.textSecondary,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Hủy',
              style: TextStyle(
                color: HomeColors.textSecondary,
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
        for (int id in _selectedIds) {
          await _databaseHelper.deleteLoan(id);
        }

        await _loadLoans();

        setState(() {
          _selectedIds.clear();
          _isSelectionMode = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Đã xóa $count khoản vay thành công',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
                '❌ Lỗi khi xóa: $e',
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

  Future<void> _navigateToAddLoan() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddLoanPage(),
      ),
    );

    if (result == true) {
      await _loadLoans();
    }
  }

  Future<void> _navigateToLoanDetail(Loan loan) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => LoanDetailScreen(loanId: loan.id!),
      ),
    );

    if (result == true) {
      await _loadLoans();
    }
  }

  Color _getLoanColor(Loan loan) {
    if (loan.loanType == 'lend') {
      return HomeColors.loanGiven;
    } else {
      return HomeColors.loanReceived;
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
    if (loan.status == 'completed') return 'Đã hoàn thành';

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
    if (status == 'Đã hoàn thành') return Colors.grey;
    return HomeColors.income;
  }

  String _getBadgeText(Loan loan) {
    return loan.isOldDebt == 0 ? 'MỚI' : 'CŨ';
  }

  @override
  Widget build(BuildContext context) {
    final totalLend = _loans
        .where((l) => l.loanType == 'lend')
        .fold<double>(0, (sum, l) => sum + l.amount);
    final totalBorrow = _loans
        .where((l) => l.loanType == 'borrow')
        .fold<double>(0, (sum, l) => sum + l.amount);

    return Scaffold(
      backgroundColor: HomeColors.background,
      appBar: AppBar(
        title: Text(
          _isSelectionMode
              ? '${_selectedIds.length} đã chọn'
              : 'Khoản vay / Đi vay',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: HomeColors.primary,
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
              color: HomeColors.primary,
              boxShadow: [
                BoxShadow(
                  color: HomeColors.cardShadow,
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: HomeColors.primary),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _currentFilter,
                        isExpanded: true,
                        icon: Icon(Icons.keyboard_arrow_down, color: HomeColors.primary),
                        style: TextStyle(
                          color: HomeColors.textPrimary,
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
                : _filteredLoans.isEmpty
                    ? Center(
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
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredLoans.length,
                        itemBuilder: (context, index) {
                          final loan = _filteredLoans[index];
                          final isSelected = _selectedIds.contains(loan.id);
                          final loanColor = _getLoanColor(loan);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Material(
                              borderRadius: BorderRadius.circular(12),
                              color: isSelected
                                  ? HomeColors.primary.withValues(alpha: 0.1)
                                  : HomeColors.cardBackground,
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
                                    borderRadius: BorderRadius.circular(12),
                                    border: isSelected
                                        ? Border.all(color: HomeColors.primary, width: 2)
                                        : null,
                                    boxShadow: !isSelected
                                        ? [
                                            BoxShadow(
                                              color: HomeColors.cardShadow,
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
                                                    style: const TextStyle(
                                                      color: HomeColors.textPrimary,
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

                                      // Amount
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: HomeColors.cardShadow,
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
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: HomeColors.textSecondary,
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
