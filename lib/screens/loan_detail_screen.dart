// Task: Build a Flutter Loan Management screen
// Features: Loan Detail Screen, layout đẹp, nút chỉnh sửa (dialog đang phát triển)
import 'package:flutter/material.dart';
import '../models/loan.dart';
import '../utils/currency_formatter.dart';
import '../database/database_helper.dart';

class LoanDetailScreen extends StatefulWidget {
  final int loanId;
  final Loan? loan;

  const LoanDetailScreen({
    Key? key,
    this.loanId = 0,
    this.loan,
  }) : super(key: key);

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
      print('Error loading loan data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String getTypeText() {
    if (_loan == null) return '';
    return _loan!.loanType == 'lend' ? 'Cho vay' : 'Đi vay';
  }

  String getStatusText() {
    if (_loan == null) return '';
    switch (_loan!.status) {
      case 'active':
        return 'Đang hoạt động';
      case 'paid':
        return 'Đã thanh toán';
      case 'overdue':
        return 'Quá hạn';
      default:
        return 'Không xác định';
    }
  }

  String getBadgeText() {
    if (_loan == null) return '';
    return _loan!.isOldDebt == 0 ? 'MỚI' : 'CŨ';
  }

  void showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thông báo'),
        content: const Text('🛠️ Tính năng chỉnh sửa đang được phát triển.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    if (_loan == null) return Colors.black;
    switch (_loan!.status) {
      case 'active':
        return Colors.green;
      case 'paid':
        return Colors.blue;
      case 'overdue':
        return Colors.red;
      default:
        return Colors.black;
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor, TextStyle? valueStyle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: const Color(0xFF00A8CC)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            style: valueStyle ?? TextStyle(fontSize: 16, color: valueColor ?? Colors.black),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00A8CC)),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết khoản vay'),
        backgroundColor: const Color(0xFF00A8CC), // Ocean blue - màu xanh nước biển của cá heo
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => showEditDialog(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loan == null
              ? const Center(
                  child: Text(
                    'Không tìm thấy thông tin khoản vay',
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header with ID and Badge
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'ID: ${_loan!.id}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Color(0xFF00A8CC),
                                      )
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _loan!.isOldDebt == 0
                                            ? const Color(0xFF00A8CC).withOpacity(0.1)
                                            : Colors.grey[300],
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        getBadgeText(),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: _loan!.isOldDebt == 0
                                              ? const Color(0xFF00A8CC)
                                              : Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Personal Information Section
                                _buildInfoSection('Thông tin cá nhân', [
                                  _buildInfoRow(Icons.person, 'Tên người', _loan!.personName),
                                  if (_loan!.personPhone != null)
                                    _buildInfoRow(Icons.phone, 'Số điện thoại', _loan!.personPhone!),
                                ]),

                                const SizedBox(height: 20),

                                // Loan Information Section
                                _buildInfoSection('Thông tin khoản vay', [
                                  _buildInfoRow(
                                    _loan!.loanType == 'lend' ? Icons.arrow_upward : Icons.arrow_downward,
                                    'Loại',
                                    getTypeText(),
                                    valueColor: _loan!.loanType == 'lend'
                                        ? const Color(0xFF00CEC9)
                                        : const Color(0xFF74B9FF),
                                  ),
                                  _buildInfoRow(
                                    Icons.attach_money,
                                    'Số tiền',
                                    CurrencyFormatter.formatVND(_loan!.amount),
                                    valueStyle: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF00A8CC),
                                    ),
                                  ),
                                  _buildInfoRow(
                                    Icons.calendar_today,
                                    'Ngày cho vay',
                                    '${_loan!.loanDate.day}/${_loan!.loanDate.month}/${_loan!.loanDate.year}'
                                  ),
                                  if (_loan!.dueDate != null)
                                    _buildInfoRow(
                                      Icons.schedule,
                                      'Ngày hết hạn',
                                      '${_loan!.dueDate!.day}/${_loan!.dueDate!.month}/${_loan!.dueDate!.year}'
                                    ),
                                  _buildInfoRow(
                                    Icons.info_outline,
                                    'Trạng thái',
                                    getStatusText(),
                                    valueColor: _getStatusColor(),
                                  ),
                                ]),

                                const SizedBox(height: 20),

                                // Additional Information Section
                                if (_loan!.description != null && _loan!.description!.isNotEmpty || _loan!.paidDate != null)
                                  _buildInfoSection('Thông tin bổ sung', [
                                    if (_loan!.description != null && _loan!.description!.isNotEmpty)
                                      _buildInfoRow(Icons.note, 'Ghi chú', _loan!.description!),
                                    if (_loan!.paidDate != null)
                                      _buildInfoRow(
                                        Icons.check_circle,
                                        'Ngày thanh toán',
                                        '${_loan!.paidDate!.day}/${_loan!.paidDate!.month}/${_loan!.paidDate!.year}',
                                        valueColor: Colors.green,
                                      ),
                                  ]),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}