import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../models/loan.dart';
import '../../utils/currency_formatter.dart';
import '../../providers/notification_provider.dart';

class EditLoanScreen extends StatefulWidget {
  final Loan loan;

  const EditLoanScreen({
    super.key,
    required this.loan,
  });

  @override
  State<EditLoanScreen> createState() => _EditLoanScreenState();
}

class _EditLoanScreenState extends State<EditLoanScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  late TextEditingController _personNameController;
  late TextEditingController _personPhoneController;
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;

  // Form data
  late String _selectedType;
  late DateTime _loanDate;
  DateTime? _dueDate;
  late bool _reminderEnabled;
  late int _reminderDays;
  late bool _isOldDebt;

  // UI state
  bool _isLoading = false;

  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeFromLoan();
    _initializeAnimations();
  }

  void _initializeFromLoan() {
    final loan = widget.loan;

    // Initialize controllers with existing data
    _personNameController = TextEditingController(text: loan.personName);
    _personPhoneController = TextEditingController(text: loan.personPhone ?? '');
    _amountController = TextEditingController(
      text: CurrencyFormatter.formatForInput(loan.amount),
    );
    _descriptionController = TextEditingController(text: loan.description ?? '');

    // Initialize form data
    _selectedType = loan.loanType;
    _loanDate = loan.loanDate;
    _dueDate = loan.dueDate;
    _reminderEnabled = loan.reminderEnabled;
    _reminderDays = loan.reminderDays ?? 3;
    _isOldDebt = loan.isOldDebt == 1;
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _personNameController.dispose();
    _personPhoneController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onTypeChanged(String type) {
    setState(() {
      _selectedType = type;
    });
  }

  Future<void> _selectLoanDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _loanDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: _getTypeColor(_selectedType),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _loanDate) {
      setState(() {
        _loanDate = picked;
      });
    }
  }

  Future<void> _selectDueDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? _loanDate.add(const Duration(days: 30)),
      firstDate: _loanDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: _getTypeColor(_selectedType),
            ),
          ),
          child: child!,
        );
      },
    );

    setState(() {
      _dueDate = picked;
    });
  }

  Future<void> _updateLoan() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final amount = CurrencyFormatter.parseAmount(_amountController.text);
      final personName = _personNameController.text.trim();
      final personPhone = _personPhoneController.text.trim().isEmpty
          ? null
          : _personPhoneController.text.trim();
      final description = _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim();

      final updatedLoan = Loan(
        id: widget.loan.id,
        personName: personName,
        personPhone: personPhone,
        amount: amount,
        loanType: _selectedType,
        loanDate: _loanDate,
        dueDate: _dueDate,
        status: widget.loan.status, // Keep existing status
        description: description,
        paidDate: widget.loan.paidDate, // Keep existing paid date
        reminderEnabled: _reminderEnabled,
        reminderDays: _reminderEnabled ? _reminderDays : null,
        lastReminderSent: widget.loan.lastReminderSent,
        isOldDebt: _isOldDebt ? 1 : 0,
        createdAt: widget.loan.createdAt,
        updatedAt: DateTime.now(),
      );

      await _databaseHelper.updateLoan(updatedLoan);

      debugPrint('✅ Loan updated successfully: ${updatedLoan.id}');

      // Check if widget is still mounted before using context
      if (!mounted) return;

      // ✅ REALTIME: Notify provider to reschedule reminders and update badge
      final notificationProvider = context.read<NotificationProvider>();
      debugPrint('🔔 Notifying provider about updated loan: ${updatedLoan.id}');
      await notificationProvider.onLoanCreatedOrUpdated(updatedLoan.id!);

      Navigator.of(context).pop(true); // Return true to indicate success
    } catch (e) {
      debugPrint('❌ Error updating loan: $e');
      if (mounted) {
        _showErrorSnackBar('Không thể cập nhật khoản vay/nợ');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _getLoanTypeText() {
    return _selectedType == 'lend' ? 'cho vay' : 'đi vay';
  }

  Color _getTypeColor(String type) {
    return type == 'lend'
        ? const Color(0xFFFFA726) // Orange for lending
        : const Color(0xFF9575CD); // Purple for borrowing
  }

  IconData _getTypeIcon(String type) {
    return type == 'lend' ? Icons.call_made : Icons.call_received;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text(
          'Chỉnh sửa khoản vay / nợ',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _getTypeColor(_selectedType),
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTypeSelector(),
                  const SizedBox(height: 24),
                  _buildPersonNameField(),
                  const SizedBox(height: 20),
                  _buildPersonPhoneField(),
                  const SizedBox(height: 20),
                  _buildAmountField(),
                  const SizedBox(height: 20),
                  _buildDescriptionField(),
                  const SizedBox(height: 20),
                  _buildDateSelectors(),
                  const SizedBox(height: 20),
                  _buildReminderSettings(),
                  const SizedBox(height: 20),
                  _buildOldDebtToggle(),
                  const SizedBox(height: 32),
                  _buildUpdateButton(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
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
          Text(
            'Loại khoản vay',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildTypeButton('lend', 'Cho vay', Icons.call_made)),
              const SizedBox(width: 12),
              Expanded(child: _buildTypeButton('borrow', 'Đi vay', Icons.call_received)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String type, String label, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _selectedType == type;
    final color = _getTypeColor(type);

    return GestureDetector(
      onTap: () => _onTypeChanged(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : colorScheme.outline.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : colorScheme.onSurfaceVariant,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonNameField() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
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
          Text(
            _selectedType == 'lend' ? 'Tên người vay' : 'Tên người cho vay',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _personNameController,
            decoration: InputDecoration(
              hintText: 'Nhập họ tên...',
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              prefixIcon: Icon(
                Icons.person,
                color: _getTypeColor(_selectedType),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _getTypeColor(_selectedType), width: 2),
              ),
              filled: true,
              fillColor: colorScheme.surface,
            ),
            style: TextStyle(color: colorScheme.onSurface),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Vui lòng nhập tên người ${_selectedType == 'lend' ? 'vay' : 'cho vay'}';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPersonPhoneField() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
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
          Text(
            'Số điện thoại (tùy chọn)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _personPhoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: 'Nhập số điện thoại...',
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              prefixIcon: Icon(Icons.phone, color: colorScheme.onSurfaceVariant),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
              filled: true,
              fillColor: colorScheme.surface,
            ),
            style: TextStyle(color: colorScheme.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountField() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
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
          Text(
            'Số tiền',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              CurrencyInputFormatter(),
            ],
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              suffixText: 'đ',
              suffixStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              prefixIcon: Icon(
                Icons.attach_money,
                color: _getTypeColor(_selectedType),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _getTypeColor(_selectedType), width: 2),
              ),
              filled: true,
              fillColor: colorScheme.surface,
            ),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _getTypeColor(_selectedType),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Vui lòng nhập số tiền';
              }
              final amount = CurrencyFormatter.parseAmount(value);
              if (amount <= 0) {
                return 'Số tiền phải lớn hơn 0';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelectors() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
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
          Text(
            'Thông tin thời gian',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          // Loan Date
          InkWell(
            onTap: _selectLoanDate,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(12),
                color: colorScheme.surface,
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ngày vay',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${_loanDate.day}/${_loanDate.month}/${_loanDate.year}',
                        style: TextStyle(
                          fontSize: 16,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_drop_down, color: colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Due Date
          InkWell(
            onTap: _selectDueDate,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(12),
                color: colorScheme.surface,
              ),
              child: Row(
                children: [
                  Icon(Icons.event, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hạn trả (tùy chọn)',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        _dueDate != null
                            ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'
                            : 'Chưa đặt hạn trả',
                        style: TextStyle(
                          fontSize: 16,
                          color: _dueDate != null ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (_dueDate != null)
                    GestureDetector(
                      onTap: () => setState(() => _dueDate = null),
                      child: Icon(Icons.clear, color: colorScheme.onSurfaceVariant, size: 20),
                    ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_drop_down, color: colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionField() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
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
          Text(
            'Mô tả (tùy chọn)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Nhập mô tả cho khoản vay/nợ...',
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              prefixIcon: Icon(Icons.description, color: colorScheme.onSurfaceVariant),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
              filled: true,
              fillColor: colorScheme.surface,
            ),
            style: TextStyle(color: colorScheme.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildOldDebtToggle() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
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
          Text(
            'Loại khoản vay',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: Text(
              _isOldDebt ? 'Khoản vay cũ (trước khi dùng app)' : 'Khoản vay mới',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              _isOldDebt
                  ? 'Chỉ ghi nhận, không ảnh hưởng số dư hiện tại'
                  : 'Tạo giao dịch mới và cập nhật số dư',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            value: _isOldDebt,
            thumbColor: WidgetStateProperty.all(_getTypeColor(_selectedType)),
            onChanged: (value) {
              setState(() {
                _isOldDebt = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReminderSettings() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
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
          Text(
            'Cài đặt nhắc nhở',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Bật nhắc nhở'),
            subtitle: Text(_reminderEnabled
                ? 'Nhắc nhở trước $_reminderDays ngày đáo hạn'
                : 'Tắt thông báo nhắc nhở'),
            value: _reminderEnabled,
            thumbColor: WidgetStateProperty.all(_getTypeColor(_selectedType)),
            onChanged: (value) {
              setState(() {
                _reminderEnabled = value;
              });
            },
          ),
          if (_reminderEnabled) ...[
            const SizedBox(height: 12),
            Text(
              'Nhắc trước (ngày):',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [1, 3, 7, 14].map((days) {
                final isSelected = _reminderDays == days;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => setState(() => _reminderDays = days),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _getTypeColor(_selectedType).withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? _getTypeColor(_selectedType)
                                : colorScheme.outline.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          '$days',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected
                                ? _getTypeColor(_selectedType)
                                : colorScheme.onSurfaceVariant,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUpdateButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _updateLoan,
        style: ElevatedButton.styleFrom(
          backgroundColor: _getTypeColor(_selectedType),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.save),
                  const SizedBox(width: 8),
                  Text(
                    'Cập nhật khoản ${_getLoanTypeText()}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final amount = CurrencyFormatter.parseAmount(newValue.text);

    if (amount == 0) {
      return newValue.copyWith(text: '');
    }

    final formatted = CurrencyFormatter.formatForInput(amount);

    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

