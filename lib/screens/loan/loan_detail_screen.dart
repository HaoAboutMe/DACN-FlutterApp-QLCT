import 'package:flutter/material.dart';
import '../../models/loan.dart';
import '../../models/transaction.dart' as transaction_model;
import '../../utils/currency_formatter.dart';
import '../../database/database_helper.dart';
import 'edit_loan_screen.dart';
import '../main_navigation_wrapper.dart';

/// LoanDetailScreen - Màn hình chi tiết khoản vay/đi vay
/// Features: Hiển thị đầy đủ thông tin, nút chỉnh sửa, layout đẹp với Ocean Blue theme
class LoanDetailScreen extends StatefulWidget {
  final int loanId;
  final Loan? loan;

  const LoanDetailScreen({
    super.key,
    required this.loanId,
    this.loan,
  });

  @override
  State<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends State<LoanDetailScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  Loan? _loan;
  bool _isLoading = true;
  bool _dataWasModified = false; // Track if loan was edited/deleted

  @override
  void initState() {
    super.initState();
    _loadLoanData();
  }

  Future<void> _loadLoanData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      Loan? loadedLoan;

      if (widget.loan != null) {
        // Use provided loan if available
        loadedLoan = widget.loan;
      } else if (widget.loanId > 0) {
        // Load from database using loanId
        loadedLoan = await _databaseHelper.getLoanById(widget.loanId);
      }

      setState(() {
        _loan = loadedLoan;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading loan data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getTypeText() {
    if (_loan == null) return '';
    return _loan!.loanType == 'lend' ? 'Cho vay' : 'Đi vay';
  }

  String _getStatusText() {
    if (_loan == null) return '';

    // ✅ Kiểm tra trạng thái thanh toán TRƯỚC (đồng bộ với loan_list_screen)
    if (_loan!.status == 'completed' || _loan!.status == 'paid') {
      return 'Đã thanh toán';
    }

    final now = DateTime.now();
    if (_loan!.dueDate == null) return 'Đang hoạt động';
    if (_loan!.dueDate!.isBefore(now)) return 'Quá hạn';
    if (_loan!.dueDate!.difference(now).inDays <= 7) return 'Sắp hết hạn';
    return 'Đang hoạt động';
  }

  Color _getStatusColor() {
    if (_loan == null) return Colors.grey;
    final status = _getStatusText();
    if (status == 'Quá hạn') return Colors.red;
    if (status == 'Sắp hết hạn') return Colors.orange;
    if (status == 'Đã thanh toán') return const Color(0xFF4CAF50); // Green for completed
    return const Color(0xFF4CAF50); // Green for active
  }

  String _getBadgeText() {
    if (_loan == null) return '';
    return _loan!.isOldDebt == 0 ? 'MỚI' : 'CŨ';
  }

  Color _getLoanColor() {
    if (_loan == null) return const Color(0xFF00A8CC); // Default blue
    return _loan!.loanType == 'lend'
        ? const Color(0xFFFFA726)  // Orange for lending
        : const Color(0xFF9575CD); // Purple for borrowing
  }

  Future<void> _navigateToEditLoan() async {
    if (_loan == null) return;

    debugPrint('🚀 Navigating to EditLoanScreen...');

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditLoanScreen(loan: _loan!),
      ),
    );

    debugPrint('🔄 Returned from EditLoanScreen with result: $result');

    // ✅ REALTIME: Reload loan data if changes were made
    if (result == true) {
      await _loadLoanData();
      _dataWasModified = true; // Mark that data was modified

      // ✅ REALTIME: Trigger HomePage reload to update balance
      mainNavigationKey.currentState?.refreshHomePage();


      // DON'T pop here - stay on detail screen to show updated data
      // The data will be returned when user manually goes back
    }
  }

  Future<void> _markLoanAsPaid() async {
    if (_loan == null || _loan!.status == 'completed' || _loan!.status == 'paid') {
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
              _loan!.loanType == 'lend'
                  ? 'Xác nhận rằng ${_loan!.personName} đã trả nợ?'
                  : 'Xác nhận rằng bạn đã trả nợ cho ${_loan!.personName}?',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getLoanColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.attach_money,
                    color: _getLoanColor(),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Số tiền: ${CurrencyFormatter.formatVND(_loan!.amount)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _getLoanColor(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _loan!.loanType == 'lend'
                  ? '✅ Số dư sẽ được cộng thêm ${CurrencyFormatter.formatVND(_loan!.amount)}'
                  : '⚠️ Số dư sẽ bị trừ ${CurrencyFormatter.formatVND(_loan!.amount)}',
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
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Đang xử lý...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Create payment transaction
      final transactionType = _loan!.loanType == 'lend' ? 'debt_collected' : 'debt_paid';
      final description = _loan!.loanType == 'lend'
          ? 'Thu hồi nợ từ ${_loan!.personName}'
          : 'Trả nợ cho ${_loan!.personName}';

      final paymentTransaction = transaction_model.Transaction(
        amount: _loan!.amount,
        description: description,
        date: DateTime.now(),
        categoryId: null,
        loanId: _loan!.id,
        type: transactionType,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Mark loan as paid
      await _databaseHelper.markLoanAsPaid(
        loanId: _loan!.id!,
        paymentTransaction: paymentTransaction,
      );

      debugPrint('✅ Loan marked as paid successfully');

      // Close loading dialog first
      if (!mounted) return;
      Navigator.of(context).pop();

      // Reload loan data to show updated status
      await _loadLoanData();
      _dataWasModified = true; // Mark that data was modified

      // Trigger HomePage reload
      mainNavigationKey.currentState?.refreshHomePage();


      // ✅ STAY on detail screen to show updated status
      // User can see the "Đã thanh toán" badge and paid date
      // User can manually go back when they want
    } catch (e) {
      debugPrint('❌ Error marking loan as paid: $e');

      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Lỗi: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    TextStyle? valueStyle,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: valueStyle ??
                  TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? colorScheme.onSurface,
                  ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData titleIcon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
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
              Icon(titleIcon, color: colorScheme.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (!didPop) {
          // Return the modified flag when popping
          Navigator.of(context).pop(_dataWasModified);
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
            onPressed: () {
              Navigator.of(context).pop(_dataWasModified);
            },
          ),
          title: Text(
            'Chi tiết khoản vay',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          backgroundColor: theme.scaffoldBackgroundColor,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          iconTheme: IconThemeData(color: colorScheme.onSurface),
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: colorScheme.onSurface),
            onPressed: _navigateToEditLoan,
            tooltip: 'Chỉnh sửa',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Đang tải dữ liệu...',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : _loan == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Không tìm thấy thông tin khoản vay',
                        style: TextStyle(
                          fontSize: 18,
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card - ID và Badge
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getLoanColor(),
                              _getLoanColor().withValues(alpha: 0.7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: _getLoanColor().withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'ID: ${_loan!.id}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _getBadgeText(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _getLoanColor(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _loan!.personName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              CurrencyFormatter.formatVND(_loan!.amount),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _loan!.loanType == 'lend'
                                        ? Icons.arrow_upward_rounded
                                        : Icons.arrow_downward_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getTypeText(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Thông tin liên hệ
                      _buildSection(
                        title: 'Thông tin liên hệ',
                        titleIcon: Icons.person_outline,
                        children: [
                          _buildInfoRow(
                            icon: Icons.person,
                            label: 'Tên người',
                            value: _loan!.personName,
                          ),
                          if (_loan!.personPhone != null && _loan!.personPhone!.isNotEmpty)
                            _buildInfoRow(
                              icon: Icons.phone,
                              label: 'Số điện thoại',
                              value: _loan!.personPhone!,
                              valueColor: colorScheme.primary,
                            ),
                        ],
                      ),

                      // Thông tin khoản vay
                      _buildSection(
                        title: 'Thông tin khoản vay',
                        titleIcon: Icons.account_balance_wallet_outlined,
                        children: [
                          _buildInfoRow(
                            icon: Icons.attach_money,
                            label: 'Số tiền',
                            value: CurrencyFormatter.formatVND(_loan!.amount),
                            valueStyle: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _getLoanColor(),
                            ),
                          ),
                          _buildInfoRow(
                            icon: Icons.calendar_today,
                            label: 'Ngày cho vay',
                            value: '${_loan!.loanDate.day}/${_loan!.loanDate.month}/${_loan!.loanDate.year}',
                          ),
                          if (_loan!.dueDate != null)
                            _buildInfoRow(
                              icon: Icons.event,
                              label: 'Ngày hết hạn',
                              value: '${_loan!.dueDate!.day}/${_loan!.dueDate!.month}/${_loan!.dueDate!.year}',
                              valueColor: _getStatusColor(),
                            ),
                          _buildInfoRow(
                            icon: Icons.info_outline,
                            label: 'Trạng thái',
                            value: _getStatusText(),
                            valueColor: _getStatusColor(),
                            valueStyle: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(),
                            ),
                          ),
                        ],
                      ),

                      // Thông tin bổ sung (nếu có)
                      if (_loan!.description != null && _loan!.description!.isNotEmpty ||
                          _loan!.paidDate != null)
                        _buildSection(
                          title: 'Thông tin bổ sung',
                          titleIcon: Icons.notes,
                          children: [
                            if (_loan!.description != null && _loan!.description!.isNotEmpty)
                              _buildInfoRow(
                                icon: Icons.note_alt_outlined,
                                label: 'Ghi chú',
                                value: _loan!.description!,
                              ),
                            if (_loan!.paidDate != null)
                              _buildInfoRow(
                                icon: Icons.check_circle,
                                label: 'Ngày thanh toán',
                                value: '${_loan!.paidDate!.day}/${_loan!.paidDate!.month}/${_loan!.paidDate!.year}',
                                valueColor: const Color(0xFF4CAF50),
                                valueStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4CAF50),
                                ),
                              ),
                          ],
                        ),

                      const SizedBox(height: 100), // Space for FABs
                    ],
                  ),
                ),
      floatingActionButton: _loan != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Mark as Paid button (only show if loan is not paid)
                if (_loan!.status != 'completed' && _loan!.status != 'paid')
                  FloatingActionButton.extended(
                    onPressed: _markLoanAsPaid,
                    backgroundColor: const Color(0xFF4CAF50), // Green for success
                    heroTag: 'markPaid',
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: Text(
                      _loan!.loanType == 'lend' ? 'Đã thu nợ' : 'Đã trả nợ',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (_loan!.status != 'completed' && _loan!.status != 'paid')
                  const SizedBox(height: 12),
                // Edit button
                FloatingActionButton.extended(
                  onPressed: _navigateToEditLoan,
                  backgroundColor: colorScheme.primary,
                  heroTag: 'edit',
                  icon: const Icon(Icons.edit, color: Colors.white),
                  label: const Text(
                    'Chỉnh sửa',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            )
          : null,
      ), // Close PopScope
    );
  }
}

