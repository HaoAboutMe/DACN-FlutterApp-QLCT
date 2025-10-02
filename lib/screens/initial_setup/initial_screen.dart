import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../database/database_helper.dart';
import '../../models/user.dart';

class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  static Future<bool> shouldShowInitialScreen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isFirstRun') ?? true;
  }

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _balanceController = TextEditingController();

  int _currentStep = 0;
  bool _isLoading = false;

  // App colors according to Figma
  static const Color darkBlue = Color(0xFF0D1B2A);   // Header background
  static const Color brightBlue = Color(0xFF1E88E5);  // Body background & button text
  static const Color white = Colors.white;            // Button background & text
  static const Color activeGreen = Color(0xFF00C853); // Active dot indicator

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _nextStep() {
    // Validation for step 2 (name input)
    if (_currentStep == 1) {
      if (_nameController.text.trim().isEmpty) {
        _showValidationSnackbar('Vui lòng nhập tên');
        return;
      }
    }

    // Validation for step 3 (balance input)
    if (_currentStep == 2) {
      if (_balanceController.text.trim().isEmpty) {
        _showValidationSnackbar('Vui lòng nhập số dư');
        return;
      }
    }

    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeSetup();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showValidationSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: white),
        ),
        backgroundColor: Colors.red[600],
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Future<void> _completeSetup() async {
    // Final validation
    if (_nameController.text.trim().isEmpty) {
      _showValidationSnackbar('Vui lòng nhập tên của bạn');
      return;
    }

    if (_balanceController.text.trim().isEmpty) {
      _showValidationSnackbar('Vui lòng nhập số dư ban đầu');
      return;
    }

    double balance;
    try {
      balance = double.parse(_balanceController.text.replaceAll(',', ''));
    } catch (e) {
      _showValidationSnackbar('Số dư không hợp lệ');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = User(
        name: _nameController.text.trim(),
        balance: balance,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await DatabaseHelper().insertUser(user);

      // Save isFirstRun = false
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isFirstRun', false);

      // Navigate to HomePage
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        _showValidationSnackbar('Có lỗi xảy ra khi lưu thông tin: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: darkBlue,
      body: SafeArea(
        child: Column(
          children: [
            // Header Section (25% of screen height)
            Container(
              height: screenHeight * 0.25,
              width: double.infinity,
              color: darkBlue,
              child: Stack(
                children: [
                  // Back button (only show from step 2 onwards)
                  if (_currentStep > 0)
                    Positioned(
                      left: 16,
                      top: 16,
                      child: IconButton(
                        onPressed: _previousStep,
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: white,
                          size: 24,
                        ),
                      ),
                    ),

                  // Header text
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        _getHeaderText(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: white,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Body Section (55% of screen height)
            Expanded(
              flex: 55,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: brightBlue,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildWelcomeStep(),
                    _buildNameStep(),
                    _buildBalanceStep(),
                    _buildSuccessStep(),
                  ],
                ),
              ),
            ),

            // Footer Section (20% of screen height)
            Container(
              height: screenHeight * 0.20,
              color: brightBlue,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Continue Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _nextStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: white,
                          foregroundColor: brightBlue,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(brightBlue),
                          ),
                        )
                            : Text(
                          _currentStep == 3 ? 'Hoàn tất' : 'Tiếp tục',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Dot Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: index == _currentStep ? activeGreen : white.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getHeaderText() {
    switch (_currentStep) {
      case 0:
        return 'Chào mừng đến với\nWhales Spent 🐋';
      case 1:
        return 'Nhập tên của bạn để cá nhân hóa trải nghiệm';
      case 2:
        return 'Nhập số dư ban đầu để bắt đầu quản lý chi tiêu';
      case 3:
        return 'Hoàn tất thiết lập 🎉';
      default:
        return '';
    }
  }

  Widget _buildWelcomeStep() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Welcome illustration using the whale logo
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(80),
                child: Image.asset(
                  'assets/images/whales-spent-logo.png',
                  width: 120,
                  height: 120,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),

          // Updated welcome text
          Text(
            'Ứng dụng chi tiêu tốt và thông minh dành cho bạn',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // User icon illustration
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline,
                size: 60,
                color: white,
              ),
            ),

            const SizedBox(height: 20),

            // Descriptive text
            Text(
              'Tên của bạn sẽ được dùng để hiển thị lời chào',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w300,
              ),
            ),

            const SizedBox(height: 40),

            // Name input field
            Container(
              decoration: BoxDecoration(
                color: white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _nameController,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Nhập tên của bạn',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  prefixIcon: Icon(Icons.person_outline, color: Colors.grey[400]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Money icon illustration
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                size: 60,
                color: white,
              ),
            ),

            const SizedBox(height: 20),

            // Descriptive text
            Text(
              'Số dư ban đầu sẽ là mốc để theo dõi chi tiêu',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w300,
              ),
            ),

            const SizedBox(height: 40),

            // Balance input field
            Container(
              decoration: BoxDecoration(
                color: white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _balanceController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                ],
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Nhập số dư (VND)',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  prefixIcon: Icon(Icons.attach_money, color: Colors.grey[400]),
                  suffixText: 'VND',
                  suffixStyle: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessStep() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Success icon illustration
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              size: 80,
              color: white,
            ),
          ),

          const SizedBox(height: 40),

          Text(
            'Bạn đã sẵn sàng bắt đầu\nquản lý chi tiêu thông minh!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w300,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 30),

          // Summary card
          if (_nameController.text.isNotEmpty && _balanceController.text.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: white.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tên:',
                        style: TextStyle(
                          color: white.withValues(alpha: 0.8),
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _nameController.text,
                        style: const TextStyle(
                          color: white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Số dư:',
                        style: TextStyle(
                          color: white.withValues(alpha: 0.8),
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${_balanceController.text} VND',
                        style: const TextStyle(
                          color: white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

