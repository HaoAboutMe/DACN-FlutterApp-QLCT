import 'package:flutter/material.dart';
import '../../models/quick_action_shortcut.dart';
import '../../models/category.dart';
import '../../services/quick_action_service.dart';
import '../../database/repositories/repositories.dart';
import '../../utils/icon_helper.dart';

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
    String selectedType = shortcut?.type ?? 'expense';
    int? selectedCategoryId = shortcut?.categoryId;
    String? selectedCategoryName = shortcut?.categoryName;
    String? selectedCategoryIcon = shortcut?.categoryIcon;

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
          return Container(
            height: screenHeight * 0.75, // Fixed 90% height
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Text(
                      shortcut == null ? 'Thêm phím tắt' : 'Chỉnh sửa phím tắt',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Content
                  Padding(
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
                      ],
                    ),
                  ),
                  // Actions
                  Padding(
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
                                    Navigator.pop(
                                      context,
                                      QuickActionShortcut(
                                        type: selectedType,
                                        categoryId: selectedCategoryId!,
                                        categoryName: selectedCategoryName!,
                                        categoryIcon: selectedCategoryIcon!,
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
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    IconHelper.getCategoryIcon(shortcut.categoryIcon),
                                    color: color,
                                  ),
                                ),
                                title: Text(
                                  shortcut.categoryName,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  shortcut.type == 'income' ? 'Thu nhập' : 'Chi tiêu',
                                  style: TextStyle(color: color, fontSize: 12),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 20),
                                      onPressed: () => _editShortcut(shortcut),
                                      color: Colors.blue,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 20),
                                      onPressed: () => _deleteShortcut(shortcut),
                                      color: Colors.red,
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

