import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/repositories/repositories.dart';
import '../../models/user.dart';
import '../../providers/theme_provider.dart';
import '../../providers/currency_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../category/category_management_screen.dart';
import '../budget/budget_list_screen.dart';
import '../settings/manage_shortcuts_screen.dart';
import 'about_screen.dart';
import 'user_guide_screen.dart';
import 'widgets/profile_expanded_header.dart';
import 'widgets/profile_collapsed_header.dart';
import 'widgets/profile_feature_grid.dart';
import 'widgets/profile_footer.dart';
import 'widgets/profile_settings_list.dart';
import 'widgets/profile_reminder_dialog.dart';
import 'widgets/profile_widget_dialogs.dart';


/// Màn hình Cá nhân - Lấy cảm hứng từ TPBank Mobile
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with WidgetsBindingObserver {
  User? _currentUser;
  String _userName = 'Người dùng Whales Spent';
  bool _isEditingName = false;
  final TextEditingController _nameController = TextEditingController();
  final UserRepository _userRepo = UserRepository();
  final ScrollController _scrollController = ScrollController();
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  bool _isWidgetPinned = false;
  bool _isRequestingWidget = false;

  bool get _supportsAndroidWidget =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCurrentUser();
    _loadReminderSettings();
    _checkWidgetPinStatus();
  }

  /// Handle currency selection change
  Future<void> _changeCurrency(String? newCurrency) async {
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    if (newCurrency == null || newCurrency == currencyProvider.selectedCurrency) return;

    try {
      // Update currency provider (this will also update CurrencyFormatter automatically)
      await currencyProvider.setCurrency(newCurrency);
    } catch (e) {
      print('Error changing currency: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Có lỗi khi thay đổi loại tiền: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkWidgetPinStatus();
    }
  }


  /// Tải thông tin người dùng hiện tại từ database
  Future<void> _loadCurrentUser() async {
    try {
      // Lấy danh sách tất cả users (giả sử user đầu tiên là user hiện tại)
      final users = await _userRepo.getAllUsers();

      if (users.isNotEmpty) {
        final user = users.first;
        setState(() {
          _currentUser = user;
          _userName = user.name;
          _nameController.text = user.name;
        });
      } else {
        // Nếu chưa có user nào, tạo user mặc định
        await _createDefaultUser();
      }
    } catch (e) {
      print('Lỗi tải thông tin user: $e');
      // Fallback to default values
      setState(() {
        _userName = 'Người dùng Whales Spent';
        _nameController.text = _userName;
      });
    }
  }

  /// Tạo user mặc định nếu chưa có user nào trong database
  Future<void> _createDefaultUser() async {
    try {
      final defaultUser = User(
        name: 'Người dùng Whales Spent',
        balance: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final userId = await _userRepo.insertUser(defaultUser);
      final createdUser = defaultUser.copyWith(id: userId);

      setState(() {
        _currentUser = createdUser;
        _userName = createdUser.name;
        _nameController.text = createdUser.name;
      });
    } catch (e) {
      print('Lỗi tạo user mặc định: $e');
    }
  }

  Future<void> _loadReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _reminderEnabled = prefs.getBool('reminderEnabled') ?? false;
      final hour = prefs.getInt('reminderHour') ?? 20;
      final minute = prefs.getInt('reminderMinute') ?? 0;
      _reminderTime = TimeOfDay(hour: hour, minute: minute);
    });
  }

  Future<void> _saveReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminderEnabled', _reminderEnabled);
    await prefs.setInt('reminderHour', _reminderTime.hour);
    await prefs.setInt('reminderMinute', _reminderTime.minute);
  }


  /// Chuyển đổi theme cho toàn bộ ứng dụng
  Future<void> _toggleTheme(bool isDark) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    await themeProvider.toggleTheme(isDark);
  }

  /// Lưu tên người dùng vào database
  Future<void> _saveUserName(String name) async {
    if (_currentUser == null || name.trim().isEmpty) return;

    try {
      // ✅ FIX: Lấy thông tin user mới nhất từ database để có số dư chính xác
      final latestUser = await _userRepo.getUserById(_currentUser!.id!);

      if (latestUser == null) {
        throw Exception('Không tìm thấy thông tin người dùng');
      }

      // Cập nhật CHỈ TÊN, giữ nguyên số dư và các thông tin khác từ database
      final updatedUser = latestUser.copyWith(
        name: name.trim(),
        updatedAt: DateTime.now(),
      );

      await _userRepo.updateUser(updatedUser);

      setState(() {
        _currentUser = updatedUser;
        _userName = name.trim();
        _isEditingName = false;
      });
    } catch (e) {
      print('Lỗi cập nhật tên user: $e');
      // Hiển thị thông báo lỗi
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Có lỗi xảy ra khi cập nhật tên: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Reset về tên cũ
      setState(() {
        _isEditingName = false;
        _nameController.text = _userName;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor, // Màu nền đồng bộ với AppBar
        child: SafeArea(
          top: true,
          bottom: false,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // SliverAppBar với animation
              _buildAnimatedAppBar(isDark),

              // Feature Grid Section
              SliverToBoxAdapter(
                child: _buildFeatureGrid(isDark),
              ),

              // Settings List Section
              SliverToBoxAdapter(
                child: _buildSettingsList(isDark),
              ),

              // Footer
              SliverToBoxAdapter(
                child: _buildFooter(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Xây dựng SliverAppBar với animation khi cuộn
  Widget _buildAnimatedAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 300.0,
      floating: false,
      pinned: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      foregroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      stretch: true,
      collapsedHeight: 90.0,
      flexibleSpace: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double maxHeight = 300.0;
          final double minHeight = 95.0;
          final double currentHeight = constraints.maxHeight;
          final double rawRatio = ((currentHeight - minHeight) / (maxHeight - minHeight));
          double expandRatio = rawRatio.clamp(0.0, 1.0);

          // 🔥 Ép tắt animation sớm để không còn 1 pixel mờ nào
          if (currentHeight <= minHeight + 30) {
            expandRatio = 0.0;
          }
          return Stack(
            children: [
              FlexibleSpaceBar(
                centerTitle: false,
                titlePadding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 18,
                ),
                background: expandRatio == 0
                  ? Container(color: Theme.of(context).scaffoldBackgroundColor)
                  : ProfileExpandedHeader(
                  isDark: isDark,
                  expandRatio: expandRatio,
                  isEditingName: _isEditingName,
                  userName: _userName,
                  nameController: _nameController,
                  onSaveName: () => _saveUserName(_nameController.text),
                  onCancelEdit: () {
                    setState(() {
                      _isEditingName = false;
                      _nameController.text = _userName;
                    });
                  },
                ),
                title: Container(
                  margin: const EdgeInsets.only(top: 18),
                  child: IgnorePointer(
                    ignoring: expandRatio > 0.2,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      opacity: expandRatio < 0.1 ? 1.0 : 0.0,
                      child: ProfileCollapsedHeader(
                        isDark: isDark,
                        userName: _userName,
                      ),
                    ),
                  ),
                ),
              ),
              // Nút "Chỉnh sửa thông tin" nằm ngoài FlexibleSpaceBar
              if (expandRatio > 0.99 && !_isEditingName) // Thay đổi từ 0.5 thành 0.3 (biến mất khi kéo 2/3)
                Positioned(
                  bottom: 52, // Điều chỉnh để không đè lên tên với spacing 32px
                  left: 0,
                  right: 0,
                  child: Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: expandRatio > 0.99 ? 1.0 : ((expandRatio - 0.3) / 0.35).clamp(0.0, 1.0), // Fade từ 0.3 đến 0.65
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isEditingName = true;
                          });
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5D5FEF).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF5D5FEF).withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                size: 15,
                                color: isDark ? Colors.white : const Color(0xFF5D5FEF),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Chỉnh sửa thông tin',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white : const Color(0xFF5D5FEF),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // _buildExpandedHeader and _buildCollapsedHeader methods have been extracted to:
  // widgets/profile_expanded_header.dart and widgets/profile_collapsed_header.dart

  /// Navigate to Category Management Screen
  void _navigateToCategoryManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CategoryManagementScreen(),
      ),
    );
  }

  /// Navigate to Budget Management Screen
  void _navigateToBudgetManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BudgetListScreen(),
      ),
    );
  }

  /// Navigate to About Screen
  void _navigateToAbout() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AboutScreen(),
      ),
    );
  }

  /// Navigate to User Guide Screen
  void _navigateToUserGuide() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UserGuideScreen(),
      ),
    );
  }

  /// Navigate to Manage Shortcuts Screen
  void _navigateToManageShortcuts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ManageShortcutsScreen(),
      ),
    );
  }

  /// Xây dựng Grid các tính năng chính
  Widget _buildFeatureGrid(bool isDark) {
    return ProfileFeatureGrid(
      isDark: isDark,
      onToggleTheme: () => _toggleTheme(!isDark),
      onNavigateToCategoryManagement: _navigateToCategoryManagement,
      onNavigateToBudgetManagement: _navigateToBudgetManagement,
      onShowReminderDialog: _showReminderDialog,
      onShowFeatureSnackbar: _showFeatureSnackbar,
    );
  }

  /// Xây dựng danh sách cài đặt
  Widget _buildSettingsList(bool isDark) {
    return Consumer<CurrencyProvider>(
      builder: (context, currencyProvider, child) {
        return ProfileSettingsList(
          isDark: isDark,
          selectedCurrency: currencyProvider.selectedCurrency, // Use provider directly
          onChangeCurrency: _changeCurrency,
          onShowReminderDialog: _showReminderDialog,
          onWidgetSettingTap: _handleWidgetSettingTap,
          onNavigateToAbout: _navigateToAbout,
          onNavigateToUserGuide: _navigateToUserGuide,
          onManageShortcutsTap: _navigateToManageShortcuts,
          onShowFeatureSnackbar: _showFeatureSnackbar,
          supportsAndroidWidget: _supportsAndroidWidget,
          isWidgetPinned: _isWidgetPinned,
          isRequestingWidget: _isRequestingWidget,
        );
      },
    );
  }

  /// Xây dựng Footer
  Widget _buildFooter(bool isDark) {
    return ProfileFooter(isDark: isDark);
  }

  /// Hiển thị snackbar cho các tính năng chưa implement
  void _showFeatureSnackbar(String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$featureName đang được phát triển...'),
        backgroundColor: const Color(0xFF5D5FEF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _handleWidgetSettingTap() {
    if (_isRequestingWidget) return;

    setState(() {
      _isRequestingWidget = true;
    });

    ProfileWidgetDialogs.showAddWidgetDialog(
      context: context,
      isWidgetPinned: _isWidgetPinned,
      supportsAndroidWidget: _supportsAndroidWidget,
      onPinStatusChanged: (isPinned) {
        setState(() {
          _isWidgetPinned = isPinned;
          _isRequestingWidget = false;
        });
      },
    ).then((_) {
      if (mounted) {
        setState(() {
          _isRequestingWidget = false;
        });
      }
    });
  }

  Future<void> _checkWidgetPinStatus() async {
    if (!_supportsAndroidWidget) return;
    final isPinned = await ProfileWidgetDialogs.checkWidgetPinStatus();
    if (mounted) {
      setState(() {
        _isWidgetPinned = isPinned;
      });
    }
  }

  void _showReminderDialog() {
    ProfileReminderDialog.show(
      context: context,
      reminderEnabled: _reminderEnabled,
      reminderTime: _reminderTime,
      onSave: (enabled, time) {
        setState(() {
          _reminderEnabled = enabled;
          _reminderTime = time;
        });
        _saveReminderSettings();
      },
      onRequestPermission: () {
        ProfileWidgetDialogs.showExactAlarmPermissionDialog(context);
      },
    );
  }
}