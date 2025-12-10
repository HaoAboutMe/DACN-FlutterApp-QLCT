import 'package:flutter/material.dart';
import 'dart:async';
import '../database/repositories/category_repository.dart';
import '../models/category.dart';
import '../models/icon_group.dart';
import '../utils/icon_helper.dart';

class CategoryPickerSheet extends StatefulWidget {
  final String initialType; // 'income' hoặc 'expense'
  final Category? initiallySelected;

  const CategoryPickerSheet({
    super.key,
    required this.initialType,
    this.initiallySelected,
  });

  @override
  State<CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<CategoryPickerSheet> {
  final CategoryRepository _categoryRepository = CategoryRepository();
  final TextEditingController _timKiemController = TextEditingController();
  final TextEditingController _tenDanhMucController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  Timer? _debounceTimer;

  // State variables
  bool _dangThemDanhMuc = false;
  String _loaiDanhMucDangChon = 'expense';
  IconGroup _nhomIconDangChon = IconGroup.all;
  IconData? _iconDangChon;
  String _tuKhoaTimKiem = '';

  List<Category> _danhSachDanhMuc = [];
  bool _dangTaiDuLieu = false;
  String? _loiValidation;

  @override
  void initState() {
    super.initState();
    _loaiDanhMucDangChon = widget.initialType;
    _taiDanhSachDanhMuc();
  }

  @override
  void dispose() {
    _timKiemController.dispose();
    _tenDanhMucController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Safe icon parsing method - handles both string names and numeric codePoints
  IconData _getCategoryIcon(String iconName) {
    return IconHelper.getCategoryIcon(iconName);
  }

  // Vietnamese diacritics removal utility function
  String removeVietnameseDiacritics(String str) {
    const withDiacritics = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỬÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
    const withoutDiacritics = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiioooooooooooooooooouuuuuuuuuuuuuyyyyydAAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOOOUUUUUUUUUUUUUYYYYYD';

    var result = str;
    for (int i = 0; i < withDiacritics.length; i++) {
      result = result.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }
    return result;
  }

  // Improved search matching function
  bool matchesSearch(String keyword, String name) {
    if (keyword.isEmpty) return true;

    final normalizedKeyword = removeVietnameseDiacritics(keyword.toLowerCase());
    final normalizedName = removeVietnameseDiacritics(name.toLowerCase());
    return normalizedName.contains(normalizedKeyword);
  }

  Future<void> _taiDanhSachDanhMuc() async {
    setState(() {
      _dangTaiDuLieu = true;
    });

    try {
      List<String>? danhSachIcon;

      // Lấy danh sách icon theo nhóm nếu không phải "Tất cả"
      if (_nhomIconDangChon != IconGroup.all) {
        final iconsInGroup = IconGroupHelper.getIconsByGroup(_nhomIconDangChon);
        danhSachIcon = iconsInGroup.map((icon) => icon.codePoint.toString()).toList();
      }

      // Get all categories first, then filter with Vietnamese diacritics support
      final allCategories = await _categoryRepository.searchCategories(
        type: _loaiDanhMucDangChon,
        keyword: null, // Don't filter at database level
        iconList: danhSachIcon,
      );

      // Apply Vietnamese diacritics-aware search filtering
      final filteredCategories = _tuKhoaTimKiem.isEmpty
          ? allCategories
          : allCategories.where((category) => matchesSearch(_tuKhoaTimKiem, category.name)).toList();

      setState(() {
        _danhSachDanhMuc = filteredCategories;
        _dangTaiDuLieu = false;
      });
    } catch (e) {
      setState(() {
        _dangTaiDuLieu = false;
      });
      debugPrint('Lỗi tải danh mục: $e');
    }
  }

  void _onTimKiemChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      setState(() {
        _tuKhoaTimKiem = value;
      });
      if (!_dangThemDanhMuc) {
        _taiDanhSachDanhMuc();
      }
    });
  }

  void _onNhomIconChanged(IconGroup nhom) {
    setState(() {
      _nhomIconDangChon = nhom;
    });
    if (!_dangThemDanhMuc) {
      _taiDanhSachDanhMuc();
    }
  }

  void _chuyenSangCheDoCenDanhMuc() {
    setState(() {
      _dangThemDanhMuc = true;
      _tenDanhMucController.clear();
      _iconDangChon = null;
      _loiValidation = null;
      _nhomIconDangChon = IconGroup.all;
      // Xóa từ khóa tìm kiếm để không ảnh hưởng đến việc chọn icon
      _tuKhoaTimKiem = '';
      _timKiemController.clear();
    });
  }

  void _chuyenSangCheDoChonDanhMuc() {
    setState(() {
      _dangThemDanhMuc = false;
      _tenDanhMucController.clear();
      _iconDangChon = null;
      _loiValidation = null;
      // Xóa từ khóa tìm kiếm khi quay lại
      _tuKhoaTimKiem = '';
      _timKiemController.clear();
    });
    _taiDanhSachDanhMuc();
  }

  void _onLoaiDanhMucChanged(String loai) {
    setState(() {
      _loaiDanhMucDangChon = loai;
    });
    if (!_dangThemDanhMuc) {
      _taiDanhSachDanhMuc();
    }
  }

  Future<bool> _kiemTraValidation() async {
    final tenDanhMuc = _tenDanhMucController.text.trim();

    if (tenDanhMuc.isEmpty) {
      setState(() {
        _loiValidation = 'Vui lòng nhập tên danh mục';
      });
      return false;
    }

    if (_iconDangChon == null) {
      setState(() {
        _loiValidation = 'Vui lòng chọn biểu tượng';
      });
      return false;
    }

    // Kiểm tra trùng lặp
    try {
      final exists = await _categoryRepository.existsCategoryByNameIcon(
        tenDanhMuc,
        _loaiDanhMucDangChon,
        _iconDangChon!.codePoint.toString(),
      );

      if (exists) {
        setState(() {
          _loiValidation = 'Danh mục đã tồn tại';
        });
        return false;
      }
    } catch (e) {
      setState(() {
        _loiValidation = 'Lỗi kiểm tra danh mục';
      });
      return false;
    }

    setState(() {
      _loiValidation = null;
    });
    return true;
  }

  Future<void> _themDanhMucMoi() async {
    if (!await _kiemTraValidation()) {
      return;
    }

    try {
      final danhMucMoi = Category(
        name: _tenDanhMucController.text.trim(),
        icon: _iconDangChon!.codePoint.toString(),
        type: _loaiDanhMucDangChon,
        createdAt: DateTime.now(),
      );

      await _categoryRepository.insertCategory(danhMucMoi);

      // Trả về danh mục vừa tạo
      if (mounted) {
        Navigator.of(context).pop(danhMucMoi);
      }
    } catch (e) {
      if (e.toString().contains('DUPLICATE_CATEGORY')) {
        setState(() {
          _loiValidation = 'Danh mục đã tồn tại';
        });
      } else {
        setState(() {
          _loiValidation = 'Lỗi thêm danh mục: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            top: false, // Don't add padding to top since it's a bottom sheet
            child: Column(
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8, bottom: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                _buildHeader(),

                // Content
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      // Thanh tìm kiếm - chỉ hiển thị khi không thêm danh mục mới
                      if (!_dangThemDanhMuc) _buildTimKiem(),
                      if (!_dangThemDanhMuc) const SizedBox(height: 16),

                      // Toggle loại danh mục nếu đang thêm mới
                      if (_dangThemDanhMuc) _buildToggleLoaiDanhMuc(),

                      // Chips nhóm icon - chỉ hiển thị khi đang thêm danh mục mới
                      if (_dangThemDanhMuc) _buildNhomIconChips(),
                      if (_dangThemDanhMuc) const SizedBox(height: 16),

                      // Content chính
                      if (_dangThemDanhMuc)
                        _buildFormThemDanhMuc()
                      else
                        _buildDanhSachDanhMuc(),

                      // Add extra bottom padding to ensure content is not hidden
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _dangThemDanhMuc ? 'Thêm danh mục mới' : 'Danh mục',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          if (_dangThemDanhMuc)
            TextButton(
              onPressed: _chuyenSangCheDoChonDanhMuc,
              child: Text(
                'Hủy',
                style: TextStyle(color: colorScheme.primary),
              ),
            )
          else
            FilledButton.icon(
              onPressed: _chuyenSangCheDoCenDanhMuc,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Thêm'),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimKiem() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return TextField(
      controller: _timKiemController,
      onChanged: _onTimKiemChanged,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: 'Tìm danh mục...', // Only show category search, remove icon search
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
      ),
    );
  }

  Widget _buildToggleLoaiDanhMuc() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Loại danh mục',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildToggleButton(
                'income',
                'Thu nhập',
                Icons.trending_up,
                const Color(0xFF4CAF50), // Green for income
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildToggleButton(
                'expense',
                'Chi tiêu',
                Icons.trending_down,
                const Color(0xFFF44336), // Red for expense
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildToggleButton(String value, String label, IconData icon, Color color) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _loaiDanhMucDangChon == value;

    return GestureDetector(
      onTap: () => _onLoaiDanhMucChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : colorScheme.outline.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? color : colorScheme.onSurfaceVariant,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNhomIconChips() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nhóm biểu tượng',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: IconGroup.values.map((group) {
            final isSelected = _nhomIconDangChon == group;
            return FilterChip(
              label: Text(IconGroupHelper.getGroupName(group)),
              selected: isSelected,
              onSelected: (_) => _onNhomIconChanged(group),
              backgroundColor: colorScheme.surfaceContainerHighest,
              selectedColor: colorScheme.primary.withValues(alpha: 0.1),
              checkmarkColor: colorScheme.primary,
              side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
              labelStyle: TextStyle(
                color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFormThemDanhMuc() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tên danh mục
          Text(
            'Tên danh mục',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _tenDanhMucController,
            maxLength: 30,
            style: TextStyle(color: colorScheme.onSurface),
            onChanged: (_) {
              setState(() {
                _loiValidation = null;
              });
            },
            decoration: InputDecoration(
              hintText: 'Nhập tên danh mục...',
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
              errorText: _loiValidation,
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),

          // Grid icon
          Text(
            'Chọn biểu tượng',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          _buildGridIcon(),
          const SizedBox(height: 24),

          // Nút thêm danh mục
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _coTheThemDanhMuc() ? _themDanhMucMoi : null,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Thêm danh mục',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _coTheThemDanhMuc() {
    return _tenDanhMucController.text.trim().isNotEmpty && _iconDangChon != null;
  }

  Widget _buildGridIcon() {
    // Chỉ filter theo nhóm icon, không filter theo từ khóa tìm kiếm
    // vì ở chế độ thêm danh mục không có thanh tìm kiếm
    final iconsToShow = IconGroupHelper.getIconsByGroup(_nhomIconDangChon);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 320, // Tăng chiều cao từ 200 lên 320 để hiển thị nhiều icon hơn
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header hiển thị số lượng icon
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Text(
              '${iconsToShow.length} biểu tượng có sẵn',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Grid icon với chiều cao mở rộng
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(12),
              crossAxisCount: 5, // Tăng từ 4 lên 5 cột để hiển thị nhiều icon hơn
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.0, // Đảm bảo icon vuông vắn
              children: iconsToShow.map((icon) {
                final isSelected = _iconDangChon?.codePoint == icon.codePoint;

                return GestureDetector(
                    onTap: () {
                      setState(() {
                        _iconDangChon = icon;
                        _loiValidation = null;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary.withValues(alpha: 0.15)
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outline.withValues(alpha: 0.5),
                          width: isSelected ? 2.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        size: 28, // Tăng kích thước icon từ 24 lên 28
                        color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                      ),
                    )
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDanhSachDanhMuc() {
    if (_dangTaiDuLieu) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_danhSachDanhMuc.isEmpty) {
      final theme = Theme.of(context);
      final colorScheme = theme.colorScheme;

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.category_outlined,
                size: 64,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'Không tìm thấy danh mục nào',
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _chuyenSangCheDoCenDanhMuc,
                child: Text(
                  'Thêm danh mục mới',
                  style: TextStyle(color: colorScheme.primary),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.0, // Changed from 0.8 to 1.0 for square boxes
      children: _danhSachDanhMuc.map((category) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final isSelected = widget.initiallySelected?.id == category.id;

        return GestureDetector(
          onTap: () {
            Navigator.of(context).pop(category);
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primary.withValues(alpha: 0.1)
                  : colorScheme.surfaceContainerHighest,
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.outline.withValues(alpha: 0.5),
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getCategoryIcon(category.icon),
                  size: 32,
                  color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Text(
                  category.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Hàm tiện ích để mở CategoryPickerSheet
Future<Category?> openCategoryPickerSheet(
    BuildContext context, {
      required String type,
      Category? selected,
    }) {
  return showModalBottomSheet<Category>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => CategoryPickerSheet(
      initialType: type,
      initiallySelected: selected,
    ),
  );
}
