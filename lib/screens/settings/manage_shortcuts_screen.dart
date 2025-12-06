import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/quick_action_shortcut.dart';
import '../../models/shortcut_feature.dart';
import '../../models/category.dart';
import '../../services/quick_action_service.dart';
import '../../services/widget_service.dart';
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
  final QuickActionService shortcutService;
  final String title;
  final String? helperMessage;
  final String emptyStateTitle;
  final String emptyStateSubtitle;
  final bool highlightWidgetContext;
  final bool triggerWidgetRefreshOnPop;

  const ManageShortcutsScreen({
    super.key,
    QuickActionService? shortcutService,
    String? title,
    this.helperMessage,
    String? emptyStateTitle,
    String? emptyStateSubtitle,
    this.highlightWidgetContext = false,
    this.triggerWidgetRefreshOnPop = false,
  })  : shortcutService = shortcutService ?? const QuickActionService(),
        title = title ?? 'Quản lý phím tắt',
        emptyStateTitle = emptyStateTitle ?? 'Chưa có phím tắt nào',
        emptyStateSubtitle = emptyStateSubtitle ?? 'Nhấn nút + để thêm phím tắt';

  factory ManageShortcutsScreen.widget() {
    return ManageShortcutsScreen(
      shortcutService: const QuickActionService.widget(),
      title: 'Tác vụ widget',
      helperMessage: 'Chọn tối đa ${QuickActionService.widgetMaxShortcuts} tác vụ để hiển thị trên widget màn hình chính. Mẹo: nhấn giữ widget để mở cấu hình nhanh.',
      emptyStateTitle: 'Chưa có tác vụ widget',
      emptyStateSubtitle: 'Nhấn nút + để thêm tác vụ xuất hiện trên widget.',
      highlightWidgetContext: true,
      triggerWidgetRefreshOnPop: true,
    );
  }

  @override
  State<ManageShortcutsScreen> createState() => _ManageShortcutsScreenState();
}

class _ManageShortcutsScreenState extends State<ManageShortcutsScreen> {
  late final QuickActionService _shortcutService;
  final CategoryRepository _categoryRepository = CategoryRepository();

  List<QuickActionShortcut> _shortcuts = [];
  bool _isLoading = true;
  bool _hasChanges = false; // Track if any changes were made

  @override
  void initState() {
    super.initState();
    _shortcutService = widget.shortcutService;
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
    if (_shortcuts.length >= _shortcutService.maxShortcuts) {
      _showErrorSnackBar('Đã đạt giới hạn ${_shortcutService.maxShortcuts} phím tắt');
      return;
    }

    final result = await _showShortcutDialog();
    if (result != null) {
      final isDuplicate = result.isFeatureShortcut
          ? _shortcuts.any((s) => s.isFeatureShortcut && s.featureId == result.featureId)
          : _shortcuts.any((s) => s.isCategoryShortcut && s.categoryId == result.categoryId);

      if (isDuplicate) {
        final label = result.displayDescription;
        _showErrorSnackBar('${result.isFeatureShortcut ? 'Chức năng' : 'Danh mục'} "$label" đã tồn tại trong danh sách');
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
      final isDuplicate = result.isFeatureShortcut
          ? _shortcuts.any((s) =>
              s.id != shortcut.id && s.isFeatureShortcut && s.featureId == result.featureId,
            )
          : _shortcuts.any((s) =>
              s.id != shortcut.id && s.isCategoryShortcut && s.categoryId == result.categoryId,
            );

      if (isDuplicate) {
        final label = result.displayDescription;
        _showErrorSnackBar('${result.isFeatureShortcut ? 'Chức năng' : 'Danh mục'} "$label" đã được thêm vào phím tắt');
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

  Future<void> _handleReorder(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) {
      return;
    }

    int targetIndex = newIndex;
    if (targetIndex > _shortcuts.length) {
      targetIndex = _shortcuts.length;
    }
    if (oldIndex < targetIndex) {
      targetIndex -= 1;
    }

    setState(() {
      final item = _shortcuts.removeAt(oldIndex);
      _shortcuts.insert(targetIndex, item);
    });

    final success = await _shortcutService.reorderShortcuts(_shortcuts);
    if (success) {
      _hasChanges = true;
    } else {
      _showErrorSnackBar('Không thể cập nhật thứ tự phím tắt');
      _loadShortcuts();
    }
  }

  Future<QuickActionShortcut?> _showShortcutDialog({QuickActionShortcut? shortcut}) async {
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    CurrencyFormatter.setCurrencyProvider(currencyProvider);

    String selectedShortcutKind = shortcut?.shortcutType ?? 'category';
    String selectedType = shortcut?.type ?? 'expense';
    int? selectedCategoryId = shortcut?.categoryId;
    String? selectedCategoryName = shortcut?.categoryName;
    String? selectedCategoryIcon = shortcut?.categoryIcon;
    String? selectedFeatureId = shortcut?.featureId;

    final descriptionController = TextEditingController(
      text: shortcut?.description ?? (shortcut?.isFeatureShortcut == true ? shortcut?.categoryName ?? '' : ''),
    );

    String initialAmount = '';
    if (shortcut?.amount != null && shortcut!.isCategoryShortcut) {
      if (currencyProvider.selectedCurrency == 'USD') {
        final usdAmount = currencyProvider.convertFromVND(shortcut.amount!);
        initialAmount = usdAmount.toStringAsFixed(2);
      } else {
        initialAmount = shortcut.amount!.toStringAsFixed(0);
      }
    }
    final amountController = TextEditingController(text: initialAmount);

    List<Category> categories = [];
    List<Category> filteredCategories = [];
    final features = ShortcutFeatureCatalog.features;

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
          final isFeatureMode = selectedShortcutKind == 'feature';
          final selectedFeature = ShortcutFeatureCatalog.findById(selectedFeatureId);

          void selectShortcutKind(String kind) {
            if (selectedShortcutKind == kind) return;
            setSheetState(() {
              selectedShortcutKind = kind;
              if (kind == 'feature') {
                selectedCategoryId = null;
                selectedCategoryName = null;
                selectedCategoryIcon = null;
                amountController.clear();
              } else {
                selectedFeatureId = null;
              }
            });
          }

          Widget buildShortcutKindToggle() {
            return Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Giao dịch'),
                    selected: selectedShortcutKind == 'category',
                    onSelected: (value) => value ? selectShortcutKind('category') : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Chức năng app'),
                    selected: isFeatureMode,
                    onSelected: (value) => value ? selectShortcutKind('feature') : null,
                  ),
                ),
              ],
            );
          }

          Widget buildFeatureList() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chọn chức năng',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                ...features.map((feature) {
                  final isSelected = selectedFeatureId == feature.id;
                  return GestureDetector(
                    onTap: () {
                      setSheetState(() {
                        selectedFeatureId = feature.id;
                        selectedCategoryName = feature.title;
                        selectedCategoryIcon = feature.iconCode;
                        if (descriptionController.text.isEmpty || descriptionController.text == selectedFeature?.title) {
                          descriptionController.text = feature.title;
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? feature.color : theme.colorScheme.outline.withValues(alpha: 0.3),
                          width: isSelected ? 2 : 1,
                        ),
                        color: feature.color.withValues(alpha: isSelected ? 0.15 : 0.08),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(feature.iconData, color: feature.color, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  feature.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  feature.subtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle, color: feature.color),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                if (features.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Chưa có chức năng nào khả dụng',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
              ],
            );
          }

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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shortcut == null ? 'Thêm phím tắt' : 'Chỉnh sửa phím tắt',
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        buildShortcutKindToggle(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isFeatureMode) ...[
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
                              SizedBox(
                                height: 300,
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
                                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
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
                                          final isAlreadyUsed = _shortcuts.any((s) =>
                                              s.isCategoryShortcut &&
                                              s.categoryId == category.id &&
                                              (shortcut == null || s.id != shortcut.id));

                                          return GestureDetector(
                                            onTap: isAlreadyUsed
                                                ? null
                                                : () {
                                                    setSheetState(() {
                                                      selectedCategoryId = category.id;
                                                      selectedCategoryName = category.name;
                                                      selectedCategoryIcon = category.icon;
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
                                                  if (isAlreadyUsed)
                                                    Positioned(
                                                      top: 4,
                                                      right: 4,
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: Colors.orange.shade100,
                                                          borderRadius: BorderRadius.circular(12),
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
                            ]
                            else ...[
                              buildFeatureList(),
                            ],
                            const SizedBox(height: 24),
                            Text(
                              isFeatureMode ? 'Tên hiển thị (tùy chọn)' : 'Mô tả tùy chỉnh (tùy chọn)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isFeatureMode
                                  ? 'Để trống sẽ dùng tên chức năng mặc định'
                                  : 'Để trống sẽ sử dụng tên danh mục',
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
                                hintText: isFeatureMode ? 'Ví dụ: Quét hóa đơn' : 'Ví dụ: Tiền điện tháng 12',
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
                            if (!isFeatureMode) ...[
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
                          ],
                        ),
                      ),
                    ),
                  ),
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
                            onPressed: isFeatureMode
                                ? (selectedFeatureId == null
                                    ? null
                                    : () {
                                        final feature = ShortcutFeatureCatalog.findById(selectedFeatureId);
                                        if (feature == null) {
                                          _showErrorSnackBar('Không thể xác định chức năng đã chọn');
                                          return;
                                        }
                                        final label = descriptionController.text.trim().isNotEmpty
                                            ? descriptionController.text.trim()
                                            : feature.title;
                                        Navigator.pop(
                                          context,
                                          QuickActionShortcut(
                                            shortcutType: 'feature',
                                            featureId: feature.id,
                                            type: 'feature',
                                            categoryId: null,
                                            categoryName: feature.title,
                                            categoryIcon: feature.iconCode,
                                            description: label,
                                          ),
                                        );
                                      })
                                : (selectedCategoryId == null
                                    ? null
                                    : () {
                                        double? parsedAmount;
                                        if (amountController.text.isNotEmpty) {
                                          final rawAmount = CurrencyFormatter.parseAmount(amountController.text);
                                          if (rawAmount > 0) {
                                            final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
                                            parsedAmount = currencyProvider.convertToVND(rawAmount);
                                          }
                                        }
                                        final description = descriptionController.text.trim();
                                        Navigator.pop(
                                          context,
                                          QuickActionShortcut(
                                            shortcutType: 'category',
                                            type: selectedType,
                                            categoryId: selectedCategoryId!,
                                            categoryName: selectedCategoryName!,
                                            categoryIcon: selectedCategoryIcon!,
                                            description: description.isNotEmpty ? description : null,
                                            amount: parsedAmount,
                                          ),
                                        );
                                      }),
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
    final helperText = widget.helperMessage ?? 'Bạn có thể thêm tối đa ${_shortcutService.maxShortcuts} phím tắt nhanh';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          if (_hasChanges && widget.triggerWidgetRefreshOnPop) {
            try {
              await WidgetService.updateWidgetData();
            } catch (e) {
              debugPrint('Không thể cập nhật widget sau khi chỉnh sửa phím tắt: $e');
            }
          }
          // Pop with result indicating if changes were made
          Navigator.of(context).pop(_hasChanges);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.title,
            style: const TextStyle(color: Colors.white),
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
                    gradient: widget.highlightWidgetContext
                        ? const LinearGradient(
                            colors: [Color(0xFF203A7F), Color(0xFF14264A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: widget.highlightWidgetContext ? null : const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(12),
                    border: widget.highlightWidgetContext
                        ? null
                        : Border.all(color: const Color(0xFF90CAF9)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.highlightWidgetContext
                            ? Icons.widgets_outlined
                            : Icons.info_outline,
                        color: widget.highlightWidgetContext
                            ? const Color(0xFFFFC857)
                            : Colors.blue.shade700,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          helperText,
                          style: TextStyle(
                            color: widget.highlightWidgetContext
                                ? Colors.white
                                : Colors.blue.shade900,
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
                                widget.emptyStateTitle,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.emptyStateSubtitle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                          itemCount: _shortcuts.length,
                          onReorder: _handleReorder,
                          buildDefaultDragHandles: false,
                          itemBuilder: (context, index) {
                            final shortcut = _shortcuts[index];
                            final isFeature = shortcut.isFeatureShortcut;
                            final color = isFeature
                                ? const Color(0xFF5C6BC0)
                                : shortcut.type == 'income'
                                    ? Colors.green
                                    : Colors.red;
                            final typeLabel = isFeature
                                ? 'Chức năng'
                                : shortcut.type == 'income'
                                    ? 'Thu nhập'
                                    : 'Chi tiêu';

                            return Padding(
                              key: ValueKey('shortcut-${shortcut.id ?? index}-${shortcut.categoryName}'),
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Card(
                                elevation: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
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
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              shortcut.categoryName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
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
                                                    typeLabel,
                                                    style: TextStyle(
                                                      color: color,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                if (!isFeature)
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
                                                  )
                                                else
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.teal.withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.apps,
                                                          size: 12,
                                                          color: Colors.teal.shade700,
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          'Shortcut app',
                                                          style: TextStyle(
                                                            color: Colors.teal.shade700,
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
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
                                          ReorderableDragStartListener(
                                            index: index,
                                            child: Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Icon(
                                                Icons.drag_handle,
                                                color: theme.colorScheme.onSurfaceVariant,
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
        floatingActionButton: _shortcuts.length < _shortcutService.maxShortcuts
            ? Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: FloatingActionButton(
                  onPressed: _addShortcut,
                  backgroundColor: theme.colorScheme.primary,
                  tooltip: widget.highlightWidgetContext ? 'Thêm tác vụ widget' : 'Thêm phím tắt',
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              )
            : null,
      ),
    );
  }
}

