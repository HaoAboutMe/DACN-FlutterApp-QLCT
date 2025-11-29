import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/quick_action_shortcut.dart';
import '../../models/category.dart';
import '../../services/quick_action_service.dart';
import '../../database/repositories/repositories.dart';
import '../../utils/icon_helper.dart';
import '../../utils/currency_formatter.dart';
import '../../providers/currency_provider.dart';

/// Custom TextInputFormatter for currency input (same as add_transaction)
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    // Cho phép empty string
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Get current currency from CurrencyFormatter
    final currentCurrency = CurrencyFormatter.getCurrency();

    if (currentCurrency == 'USD') {
      // Cho USD: chỉ cho phép digits và 1 dấu chấm
      String filtered = newValue.text;

      // Loại bỏ tất cả ký tự không hợp lệ
      filtered = filtered.replaceAll(RegExp(r'[^0-9.]'), '');

      // Đảm bảo chỉ có 1 dấu chấm
      final parts = filtered.split('.');
      if (parts.length > 2) {
        filtered = parts[0] + '.' + parts.sublist(1).join('');
      }

      // Giới hạn 3 chữ số thập phân
      if (parts.length == 2 && parts[1].length > 3) {
        filtered = parts[0] + '.' + parts[1].substring(0, 3);
      }

      return newValue.copyWith(
        text: filtered,
        selection: TextSelection.collapsed(offset: filtered.length),
      );
    } else {
      // Cho VND: chỉ cho phép digits và dấu phẩy
      String filtered = newValue.text.replaceAll(RegExp(r'[^0-9,]'), '');

      // Auto-format với dấu phẩy ngăn cách hàng nghìn cho VND
      if (filtered.isNotEmpty) {
        final digitsOnly = filtered.replaceAll(',', '');
        if (digitsOnly.isNotEmpty) {
          final amount = double.tryParse(digitsOnly) ?? 0;
          if (amount > 0) {
            final formatter = NumberFormat('#,###', 'vi_VN');
            filtered = formatter.format(amount);
          }
        }
      }

      return newValue.copyWith(
        text: filtered,
        selection: TextSelection.collapsed(offset: filtered.length),
      );
    }
  }
}

class ManageShortcutsScreen extends StatefulWidget {
  const ManageShortcutsScreen({super.key});

  @override
  State<ManageShortcutsScreen> createState() => _ManageShortcutsScreenState();
}

class _ManageShortcutsScreenState extends State<ManageShortcutsScreen> {
  final QuickActionService _shortcutService = QuickActionService();
  final CategoryRepository _categoryRepository = CategoryRepository();

  List<QuickActionShortcut> _shortcuts = [];
  bool _isLoading = true;
  bool _hasChanges = false; // Track if any changes were made

  @override
  void initState() {
    super.initState();
    _loadShortcuts();
  }

  Future<void> _loadShortcuts() async {
    setState(() => _isLoading = true);
    try {
      final shortcuts = await _shortcutService.getShortcuts();
      setState(() {
        _shortcuts = shortcuts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Không thể tải phím tắt: $e');
    }
  }

  Future<void> _addShortcut() async {
    if (_shortcuts.length >= QuickActionService.maxShortcuts) {
      _showErrorSnackBar('Đã đạt giới hạn ${QuickActionService.maxShortcuts} phím tắt');
      return;
    }

    final result = await _showShortcutDialog();
    if (result != null) {
      // Check if category already exists in shortcuts
      final isDuplicate = _shortcuts.any((s) => s.categoryId == result.categoryId);
      if (isDuplicate) {
        _showErrorSnackBar('Danh mục "${result.categoryName}" đã được thêm vào phím tắt');
        return;
      }

      final success = await _shortcutService.addShortcut(result);
      if (success) {
        _hasChanges = true;
        _loadShortcuts();
      } else {
        _showErrorSnackBar('Không thể thêm phím tắt');
      }
    }
  }

  Future<void> _editShortcut(QuickActionShortcut shortcut) async {
    final result = await _showShortcutDialog(shortcut: shortcut);
    if (result != null && shortcut.id != null) {
      // Check if category already exists in other shortcuts (exclude current shortcut)
      final isDuplicate = _shortcuts.any((s) =>
        s.id != shortcut.id && s.categoryId == result.categoryId
      );
      if (isDuplicate) {
        _showErrorSnackBar('Danh mục "${result.categoryName}" đã được thêm vào phím tắt');
        return;
      }

      final success = await _shortcutService.updateShortcut(shortcut.id!, result);
      if (success) {
        _hasChanges = true;
        _loadShortcuts();
      } else {
        _showErrorSnackBar('Không thể cập nhật phím tắt');
      }
    }
  }

  Future<void> _deleteShortcut(QuickActionShortcut shortcut) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa phím tắt "${shortcut.categoryName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && shortcut.id != null) {
      final success = await _shortcutService.deleteShortcut(shortcut.id!);
      if (success) {
        _hasChanges = true;
        _loadShortcuts();
      } else {
        _showErrorSnackBar('Không thể xóa phím tắt');
      }
    }
  }

  Future<QuickActionShortcut?> _showShortcutDialog({QuickActionShortcut? shortcut}) async {
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    CurrencyFormatter.setCurrencyProvider(currencyProvider);

    String selectedType = shortcut?.type ?? 'expense';
    int? selectedCategoryId = shortcut?.categoryId;
    String? selectedCategoryName = shortcut?.categoryName;
    String? selectedCategoryIcon = shortcut?.categoryIcon;

    // Controllers for text input
    final descriptionController = TextEditingController(text: shortcut?.description ?? '');

    // Initialize amount controller with proper currency conversion
    String initialAmount = '';
    if (shortcut?.amount != null) {
      // When editing existing shortcut, convert stored VND amount to current currency
      if (currencyProvider.selectedCurrency == 'USD') {
        // Convert VND to USD for display
        final usdAmount = currencyProvider.convertFromVND(shortcut!.amount!);
        initialAmount = usdAmount.toStringAsFixed(2);
      } else {
        // VND - show as is
        initialAmount = shortcut!.amount!.toStringAsFixed(0);
      }
    }
    // For new shortcuts, leave empty - user will input in current currency
    final amountController = TextEditingController(text: initialAmount);

    List<Category> categories = [];
    List<Category> filteredCategories = [];

    // Load categories
    try {
      categories = await _categoryRepository.getAllCategories();
      filteredCategories = categories.where((c) => c.type == selectedType).toList();
    } catch (e) {
      _showErrorSnackBar('Không thể tải danh mục');
      return null;
    }

    return await showModalBottomSheet<QuickActionShortcut>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final theme = Theme.of(context);
          final screenHeight = MediaQuery.of(context).size.height;
          final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

          return Padding(
            padding: EdgeInsets.only(bottom: keyboardHeight),
            child: Container(
              height: screenHeight * 0.85,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Title
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Text(
                      shortcut == null ? 'Thêm phím tắt' : 'Chỉnh sửa phím tắt',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                          'Loại giao dịch',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTypeCard(
                                context,
                                'income',
                                'Thu nhập',
                                Icons.trending_up,
                                selectedType == 'income',
                                () {
                                  setSheetState(() {
                                    selectedType = 'income';
                                    filteredCategories = categories.where((c) => c.type == selectedType).toList();
                                    selectedCategoryId = null;
                                    selectedCategoryName = null;
                                    selectedCategoryIcon = null;
                                    descriptionController.clear();
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTypeCard(
                                context,
                                'expense',
                                'Chi tiêu',
                                Icons.trending_down,
                                selectedType == 'expense',
                                () {
                                  setSheetState(() {
                                    selectedType = 'expense';
                                    filteredCategories = categories.where((c) => c.type == selectedType).toList();
                                    selectedCategoryId = null;
                                    selectedCategoryName = null;
                                    selectedCategoryIcon = null;
                                    descriptionController.clear();
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Danh mục',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Category grid with fixed height to prevent layout shifts
                        SizedBox(
                          height: 300, // Fixed height for grid container
                          child: filteredCategories.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Không có danh mục nào',
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                )
                              : GridView.builder(
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 1,
                                  ),
                                  itemCount: filteredCategories.length,
                                  itemBuilder: (context, index) {
                                    final category = filteredCategories[index];
                                    final isSelected = selectedCategoryId == category.id;
                                    final color = selectedType == 'income' ? Colors.green : Colors.red;

                                    // Check if category is already used in another shortcut
                                    final isAlreadyUsed = _shortcuts.any((s) =>
                                      s.categoryId == category.id &&
                                      (shortcut == null || s.id != shortcut.id)
                                    );

                                    return GestureDetector(
                                      onTap: isAlreadyUsed ? null : () {
                                        setSheetState(() {
                                          selectedCategoryId = category.id;
                                          selectedCategoryName = category.name;
                                          selectedCategoryIcon = category.icon;
                                          // Auto-fill description with category name
                                          descriptionController.text = category.name;
                                        });
                                      },
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            AnimatedContainer(
                                              duration: const Duration(milliseconds: 200),
                                              decoration: BoxDecoration(
                                                color: isAlreadyUsed
                                                    ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                                                    : isSelected
                                                        ? color.withValues(alpha: 0.1)
                                                        : theme.colorScheme.surfaceContainerHighest,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: isAlreadyUsed
                                                      ? theme.colorScheme.outline.withValues(alpha: 0.2)
                                                      : isSelected
                                                          ? color
                                                          : theme.colorScheme.outline.withValues(alpha: 0.3),
                                                  width: isSelected ? 2 : 1,
                                                ),
                                              ),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    IconHelper.getCategoryIcon(category.icon),
                                                    size: 32,
                                                    color: isAlreadyUsed
                                                        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3)
                                                        : isSelected
                                                            ? color
                                                            : theme.colorScheme.onSurfaceVariant,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                                    child: Text(
                                                      category.name,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                        color: isAlreadyUsed
                                                            ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3)
                                                            : isSelected
                                                                ? color
                                                                : theme.colorScheme.onSurfaceVariant,
                                                      ),
                                                      textAlign: TextAlign.center,
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Badge "Đã dùng" for already used categories
                                            if (isAlreadyUsed)
                                              Positioned(
                                                top: 4,
                                                right: 4,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange.shade100,
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(
                                                      color: Colors.orange.shade300,
                                                      width: 0.5,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    'Đã dùng',
                                                    style: TextStyle(
                                                      fontSize: 7,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.orange.shade900,
                                                      height: 1,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        // Mô tả tùy chỉnh
                        const SizedBox(height: 24),
                        Text(
                          'Mô tả tùy chỉnh (tùy chọn)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Để trống sẽ sử dụng tên danh mục',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: descriptionController,
                          decoration: InputDecoration(
                            hintText: 'Ví dụ: Tiền điện tháng 12',
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerHighest,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: theme.colorScheme.primary,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        // Số tiền
                        const SizedBox(height: 24),
                        Text(
                          'Số tiền (tùy chọn)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Để trống: Dẫn đến trang thêm giao dịch\nĐiền số tiền: Thêm trực tiếp không cần màn hình trung gian',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Consumer<CurrencyProvider>(
                          builder: (context, currencyProvider, child) {
                            final currencySymbol = currencyProvider.currencySymbol;
                            final isUsd = currencyProvider.selectedCurrency == 'USD';

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: amountController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [
                                    CurrencyInputFormatter(),
                                  ],
                                  decoration: InputDecoration(
                                    hintText: isUsd ? 'Ví dụ: 20.00' : 'Ví dụ: 500.000',
                                    prefixIcon: Icon(Icons.attach_money, color: theme.colorScheme.primary),
                                    suffixText: currencySymbol,
                                    suffixStyle: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    filled: true,
                                    fillColor: theme.colorScheme.surfaceContainerHighest,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: theme.colorScheme.primary,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                                // Helper text for USD
                                if (isUsd) ...[
                                  const SizedBox(height: 8),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 12),
                                    child: Text(
                                      'Sẽ được chuyển đổi thành VND khi lưu (tỷ giá: 1 USD = ${currencyProvider.exchangeRate.toStringAsFixed(0)} VND)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurfaceVariant,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Actions - Fixed at bottom
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Hủy'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: selectedCategoryId == null
                                ? null
                                : () {
                              double? parsedAmount;

                              if (amountController.text.isNotEmpty) {
                                // 1. Parse amount theo currency hiện tại (USD hoặc VND)
                                final rawAmount = CurrencyFormatter.parseAmount(amountController.text);

                                if (rawAmount > 0) {
                                  // 2. Convert về VND để lưu vào DB (giống AddTransaction)
                                  final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
                                  parsedAmount = currencyProvider.convertToVND(rawAmount);
                                }
                              }

                              final description = descriptionController.text.trim();

                              Navigator.pop(
                                context,
                                QuickActionShortcut(
                                  type: selectedType,
                                  categoryId: selectedCategoryId!,
                                  categoryName: selectedCategoryName!,
                                  categoryIcon: selectedCategoryIcon!,
                                  description: description.isNotEmpty ? description : null,
                                  amount: parsedAmount, // luôn là VND
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(shortcut == null ? 'Thêm' : 'Cập nhật'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTypeCard(
    BuildContext context,
    String type,
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    final color = type == 'income' ? Colors.green : Colors.red;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : theme.colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          // Pop with result indicating if changes were made
          Navigator.of(context).pop(_hasChanges);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Quản lý phím tắt',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Info card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD), // Light blue - same for both modes
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF90CAF9)), // Blue border
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Bạn có thể thêm tối đa ${QuickActionService.maxShortcuts} phím tắt nhanh',
                          style: TextStyle(
                            color: Colors.blue.shade900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Shortcuts list
                Expanded(
                  child: _shortcuts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.touch_app_outlined,
                                size: 80,
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Chưa có phím tắt nào',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Nhấn nút + để thêm phím tắt',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _shortcuts.length,
                          itemBuilder: (context, index) {
                            final shortcut = _shortcuts[index];
                            final color = shortcut.type == 'income' ? Colors.green : Colors.red;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    // Icon
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        IconHelper.getCategoryIcon(shortcut.categoryIcon),
                                        color: color,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Category name
                                          Text(
                                            shortcut.categoryName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          // Type
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: color.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  shortcut.type == 'income' ? 'Thu nhập' : 'Chi tiêu',
                                                  style: TextStyle(
                                                    color: color,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // Mode badge
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: shortcut.isQuickAddMode
                                                      ? Colors.blue.withValues(alpha: 0.1)
                                                      : Colors.orange.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      shortcut.isQuickAddMode
                                                          ? Icons.flash_on
                                                          : Icons.edit_note,
                                                      size: 12,
                                                      color: shortcut.isQuickAddMode
                                                          ? Colors.blue.shade700
                                                          : Colors.orange.shade700,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      shortcut.isQuickAddMode ? 'Quick Add' : 'Template',
                                                      style: TextStyle(
                                                        color: shortcut.isQuickAddMode
                                                            ? Colors.blue.shade700
                                                            : Colors.orange.shade700,
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          // Custom description (if different from category name)
                                          if (shortcut.description != null &&
                                              shortcut.description!.isNotEmpty &&
                                              shortcut.description != shortcut.categoryName) ...[
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.description,
                                                  size: 14,
                                                  color: theme.colorScheme.onSurfaceVariant,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    shortcut.description!,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: theme.colorScheme.onSurfaceVariant,
                                                      fontStyle: FontStyle.italic,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                          // Amount (if in Quick Add mode)
                                          if (shortcut.isQuickAddMode) ...[
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.attach_money,
                                                  size: 14,
                                                  color: color,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  CurrencyFormatter.formatAmount(shortcut.amount!),
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: color,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    // Actions
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 20),
                                          onPressed: () => _editShortcut(shortcut),
                                          color: Colors.blue,
                                          tooltip: 'Chỉnh sửa',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, size: 20),
                                          onPressed: () => _deleteShortcut(shortcut),
                                          color: Colors.red,
                                          tooltip: 'Xóa',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: _shortcuts.length < QuickActionService.maxShortcuts
          ? Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: FloatingActionButton(
                onPressed: _addShortcut,
                backgroundColor: theme.colorScheme.primary,
                child: const Icon(Icons.add, color: Colors.white),
              ),
            )
          : null,
      ),
    );
  }
}

