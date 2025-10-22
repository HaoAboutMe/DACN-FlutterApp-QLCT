import 'package:flutter/material.dart';
import '../../models/loan.dart';
import '../../utils/currency_formatter.dart';
import '../../database/database_helper.dart';
import '../home/home_colors.dart';
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
    if (_loan!.status == 'completed') return 'Đã hoàn thành';

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
    if (status == 'Đã hoàn thành') return Colors.grey;
    return HomeColors.income;
  }

  String _getBadgeText() {
    if (_loan == null) return '';
    return _loan!.isOldDebt == 0 ? 'MỚI' : 'CŨ';
  }

  Color _getLoanColor() {
    if (_loan == null) return HomeColors.primary;
    return _loan!.loanType == 'lend' ? HomeColors.loanGiven : HomeColors.loanReceived;
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

      // Return true to notify parent screens (e.g., LoanListScreen)
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    TextStyle? valueStyle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: HomeColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: HomeColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: HomeColors.textSecondary,
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
                    color: valueColor ?? HomeColors.textPrimary,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HomeColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
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
              Icon(titleIcon, color: HomeColors.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: HomeColors.primary,
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
    return Scaffold(
      backgroundColor: HomeColors.background,
      appBar: AppBar(
        title: const Text(
          'Chi tiết khoản vay',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: HomeColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
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
          : _loan == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Không tìm thấy thông tin khoản vay',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
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
                              valueColor: HomeColors.primary,
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
                                valueColor: HomeColors.income,
                                valueStyle: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: HomeColors.income,
                                ),
                              ),
                          ],
                        ),

                      const SizedBox(height: 80), // Space for FAB
                    ],
                  ),
                ),
      floatingActionButton: _loan != null
          ? FloatingActionButton.extended(
              onPressed: _navigateToEditLoan,
              backgroundColor: HomeColors.primary,
              icon: const Icon(Icons.edit, color: Colors.white),
              label: const Text(
                'Chỉnh sửa',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }
}

