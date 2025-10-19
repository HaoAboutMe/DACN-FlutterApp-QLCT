import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/loan.dart';
import '../../utils/currency_formatter.dart';
import '../home/home_colors.dart';
import '../add_loan/add_loan_page.dart';

class LoanListScreen extends StatefulWidget {
  const LoanListScreen({super.key});

  @override
  State<LoanListScreen> createState() => _LoanListScreenState();
}

class _LoanListScreenState extends State<LoanListScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  List<Loan> _loans = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, lend, borrow, active, completed

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
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading loans: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Loan> get _filteredLoans {
    if (_selectedFilter == 'all') {
      return _loans;
    } else if (_selectedFilter == 'lend') {
      return _loans.where((loan) => loan.loanType == 'lend').toList();
    } else if (_selectedFilter == 'borrow') {
      return _loans.where((loan) => loan.loanType == 'borrow').toList();
    } else if (_selectedFilter == 'active') {
      return _loans.where((loan) => loan.status == 'active').toList();
    } else if (_selectedFilter == 'completed') {
      return _loans.where((loan) => loan.status == 'completed').toList();
    }
    return _loans;
  }

  Color _getLoanColor(Loan loan) {
    if (loan.loanType == 'lend') {
      return loan.status == 'active' ? Colors.green : Colors.green.withValues(alpha: 0.5);
    } else {
      return loan.status == 'active' ? Colors.orange : Colors.orange.withValues(alpha: 0.5);
    }
  }

  IconData _getLoanIcon(Loan loan) {
    if (loan.loanType == 'lend') {
      return Icons.call_made;
    } else {
      return Icons.call_received;
    }
  }

  String _getLoanTypeText(Loan loan) {
    if (loan.loanType == 'lend') {
      return 'Cho vay';
    } else {
      return 'Đi vay';
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'active':
        return 'Đang hoạt động';
      case 'completed':
        return 'Đã hoàn thành';
      default:
        return 'Không xác định';
    }
  }

  Future<void> _navigateToLoanDetail(Loan loan) async {
    // Tạm thời hiển thị thông tin loan trong dialog cho đến khi có LoanDetailScreen
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Chi tiết khoản ${_getLoanTypeText(loan).toLowerCase()}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Người: ${loan.personName}'),
            const SizedBox(height: 8),
            Text('Số tiền: ${CurrencyFormatter.formatVND(loan.amount)}'),
            const SizedBox(height: 8),
            Text('Ngày: ${loan.loanDate.day}/${loan.loanDate.month}/${loan.loanDate.year}'),
            const SizedBox(height: 8),
            Text('Trạng thái: ${_getStatusText(loan.status)}'),
            if (loan.description != null) ...[
              const SizedBox(height: 8),
              Text('Mô tả: ${loan.description}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToAddLoan() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddLoanPage(),
      ),
    );

    if (result == true) {
      await _loadLoans(); // Refresh data after adding new loan
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeColors.background,
      appBar: AppBar(
        title: const Text(
          'Quản lý Khoản vay',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: HomeColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _navigateToAddLoan,
            icon: const Icon(Icons.add),
            tooltip: 'Thêm khoản vay mới',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter tabs
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: _buildFilterTab('all', 'Tất cả')),
                const SizedBox(width: 8),
                Expanded(child: _buildFilterTab('lend', 'Cho vay')),
                const SizedBox(width: 8),
                Expanded(child: _buildFilterTab('borrow', 'Đi vay')),
              ],
            ),
          ),
          // Secondary filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _buildFilterTab('active', 'Đang hoạt động')),
                const SizedBox(width: 8),
                Expanded(child: _buildFilterTab('completed', 'Đã hoàn thành')),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Loans list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(HomeColors.primary),
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
                              'Chưa có khoản vay nào',
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
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredLoans.length,
                        itemBuilder: (context, index) {
                          final loan = _filteredLoans[index];
                          final loanColor = _getLoanColor(loan);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _navigateToLoanDetail(loan),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    // Icon
                                    Container(
                                      width: 48,
                                      height: 48,
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
                                    const SizedBox(width: 16),
                                    // Content
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            loan.personName,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
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
                                                Icons.schedule,
                                                size: 14,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${loan.loanDate.day}/${loan.loanDate.month}/${loan.loanDate.year}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: loan.status == 'active'
                                                      ? Colors.green.withValues(alpha: 0.1)
                                                      : Colors.grey.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  _getStatusText(loan.status),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: loan.status == 'active'
                                                        ? Colors.green[700]
                                                        : Colors.grey[600],
                                                    fontWeight: FontWeight.w500,
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
                                        if (loan.dueDate != null)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text(
                                              'Đến hạn: ${loan.dueDate!.day}/${loan.dueDate!.month}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddLoan,
        backgroundColor: HomeColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFilterTab(String value, String label) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? HomeColors.primary : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
