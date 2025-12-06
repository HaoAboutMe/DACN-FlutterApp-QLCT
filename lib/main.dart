import 'package:app_qlct/utils/notification_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'config/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/currency_provider.dart';
import 'services/notification_service.dart';
import 'services/widget_service.dart';
import 'database/repositories/repositories.dart';
import 'screens/add_transaction/add_transaction_page.dart';
import 'screens/budget/budget_list_screen.dart';
import 'screens/initial_setup/initial_screen.dart';
import 'screens/main_navigation_wrapper.dart';
import 'screens/receipt_scan/receipt_scan_screen.dart';
import 'screens/settings/manage_shortcuts_screen.dart';
import 'screens/backup/backup_restore_screen.dart';
import 'utils/currency_formatter.dart';
import 'models/transaction.dart' as transaction_model;

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Vietnamese locale for date formatting
  await initializeDateFormatting('vi_VN', null);

  // Initialize notification helpers
  await NotificationHelper.initialize();

  // ✅ KHỞI TẠO NOTIFICATION SERVICE VỚI WORKMANAGER
  final notificationService = NotificationService();
  await notificationService.initialize();

  // ✅ CHECK LOAN REMINDERS KHI APP MỞ
  try {
    await notificationService.checkAndCreateLoanReminders();
    debugPrint('✅ Loan reminders checked on startup');
  } catch (e) {
    debugPrint('❌ Error checking loan reminders: $e');
  }

  // Initialize default categories if database is empty
  try {
    final categoryRepo = CategoryRepository();
    await categoryRepo.insertDefaultCategoriesIfNeeded();
  } catch (e) {
    debugPrint('Error initializing default categories: $e');
  }

  // ✅ CẬP NHẬT WIDGET KHI APP MỞ
  try {
    debugPrint('🔄 Updating home screen widget...');
    await WidgetService.updateWidgetData();
  } catch (e) {
    debugPrint('❌ Error updating widget on startup: $e');
  }

  // Setup MethodChannel để nhận intent từ widget
  setupWidgetChannel();

  // Check if InitialScreen should be shown
  final isFirstRun = await InitialScreen.shouldShowInitialScreen();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(
          create: (_) {
            final provider = CurrencyProvider();
            CurrencyFormatter.setCurrencyProvider(provider);
            return provider;
          },
        ),
      ],
      child: MyApp(isFirstRun: isFirstRun),
    ),
  );
}

/// Setup MethodChannel để nhận message từ Android widget
void setupWidgetChannel() {
  const channel = MethodChannel('com.example.app_qlct/widget');

  channel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'openTab':
        final int tabIndex = call.arguments as int;
        debugPrint('📱 Widget clicked - Opening tab $tabIndex');
        _handleOpenTab(tabIndex);
        break;
      case 'openWidgetShortcutManager':
        await _openWidgetShortcutManager();
        break;
      case 'handleQuickAction':
        if (call.arguments is Map) {
          final payload = Map<String, dynamic>.from(call.arguments as Map);
          await _handleQuickActionFromWidget(payload);
        }
        break;
      default:
        break;
    }
  });
}

class MyApp extends StatelessWidget {
  final bool isFirstRun;

  const MyApp({super.key, required this.isFirstRun});

  @override
  Widget build(BuildContext context) {
    // Khởi tạo notification provider khi app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notificationProvider = context.read<NotificationProvider>();
      notificationProvider.initialize();
      // Kiểm tra và tạo reminder khi mở app
      notificationProvider.checkAndCreateReminders();
    });

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Whales Spent',
          navigatorKey: rootNavigatorKey,
          // Sử dụng theme tùy chỉnh
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          // Show InitialScreen or MainNavigationWrapper based on isFirstRun
          home: isFirstRun
              ? const InitialScreen()
              : MainNavigationWrapper(
                  key: mainNavigationKey,
                  initialIndex: pendingWidgetTabNotifier.value ?? 0,
                ),
          // Define named routes
          routes: {
            '/home': (context) => MainNavigationWrapper(
              key: mainNavigationKey,
              initialIndex: pendingWidgetTabNotifier.value ?? 0,
            ),
            '/initial': (context) => const InitialScreen(),
            '/backup-restore': (context) => const BackupRestoreScreen(),
          },
          debugShowCheckedModeBanner: false, // Remove debug banner
        );
      },
    );
  }
}

void _handleOpenTab(int tabIndex) {
  rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
  final navState = mainNavigationKey.currentState;
  if (navState != null) {
    navState.switchToTab(tabIndex);
  } else {
    pendingWidgetTabNotifier.value = tabIndex;
  }
}

Future<void> _openWidgetShortcutManager() async {
  final navigator = await _resetNavigatorToRoot();
  if (navigator == null) return;

  await navigator.push(
    MaterialPageRoute(builder: (_) => ManageShortcutsScreen.widget()),
  );
}

Future<void> _handleQuickActionFromWidget(Map<String, dynamic> payload) async {
  final shortcutType = (payload['shortcut_type'] as String?) ?? 'category';
  if (shortcutType == 'feature') {
    await _handleFeatureShortcut(payload['feature_id'] as String?);
  } else {
    await _handleTransactionShortcut(payload);
  }
}

Future<void> _handleFeatureShortcut(String? featureId) async {
  switch (featureId) {
    case 'add_expense':
      await _openTransactionForm(preselectedType: 'expense');
      break;
    case 'add_income':
      await _openTransactionForm(preselectedType: 'income');
      break;
    case 'scan_receipt':
      await _pushRoute((_) => const ReceiptScanScreen());
      break;
    case 'view_budgets':
      await _pushRoute((_) => const BudgetListScreen());
      break;
    case 'open_statistics':
      _handleOpenTab(3);
      break;
    case 'open_loans':
      _handleOpenTab(2);
      break;
    default:
      break;
  }
}

Future<void> _handleTransactionShortcut(Map<String, dynamic> payload) async {
  final type = (payload['type'] as String?) ?? 'expense';
  final categoryIdValue = payload['category_id'];
  final label = (payload['label'] as String?) ?? (payload['category_name'] as String?);
  final amountValue = payload['amount'];
  final isQuickAdd = payload['is_quick_add'] == true;

  int? categoryId;
  if (categoryIdValue is int && categoryIdValue > 0) {
    categoryId = categoryIdValue;
  }

  double? initialAmount;
  if (amountValue is num && amountValue > 0) {
    initialAmount = amountValue.toDouble();
  }

  final hasQuickAddData =
      isQuickAdd && initialAmount != null && categoryId != null && initialAmount > 0;

  if (hasQuickAddData) {
    final description = label ?? 'Giao dịch nhanh';
    final confirmed = await _showQuickAddConfirmation(description, initialAmount!, type);
    if (confirmed) {
      await _performQuickAddTransaction(
        description: description,
        amount: initialAmount!,
        type: type,
        categoryId: categoryId!,
      );
    }
    return;
  }

  await _openTransactionForm(
    preselectedType: type,
    categoryId: categoryId,
    description: label,
    initialAmount: initialAmount,
  );
}

Future<void> _openTransactionForm({
  required String preselectedType,
  int? categoryId,
  String? description,
  double? initialAmount,
}) async {
  final navigator = await _resetNavigatorToRoot();
  if (navigator == null) return;

  await navigator.push(
    MaterialPageRoute(
      builder: (_) => AddTransactionPage(
        preselectedType: preselectedType,
        preselectedCategoryId: categoryId,
        preselectedDescription: description,
        initialAmount: initialAmount,
      ),
    ),
  );
}

Future<void> _pushRoute(WidgetBuilder builder) async {
  final navigator = await _resetNavigatorToRoot();
  if (navigator == null) return;

  await navigator.push(
    MaterialPageRoute(builder: builder),
  );
}

Future<bool> _showQuickAddConfirmation(String description, double amount, String type) async {
  final navigator = await _waitForNavigator();
  if (navigator == null) return false;

  final context = navigator.context;
  final formattedAmount = CurrencyFormatter.formatAmount(amount);
  final typeLabel = type == 'income' ? 'thu nhập' : 'chi tiêu';

  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Thêm $typeLabel nhanh?'),
          content: Text('Bạn có muốn thêm "$description" với số tiền $formattedAmount không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Đồng ý'),
            ),
          ],
        ),
      ) ??
      false;
}

Future<void> _performQuickAddTransaction({
  required String description,
  required double amount,
  required String type,
  required int categoryId,
}) async {
  try {
    final transactionRepo = TransactionRepository();
    final userRepo = UserRepository();
    final now = DateTime.now();

    final transaction = transaction_model.Transaction(
      amount: amount,
      description: description,
      date: now,
      categoryId: categoryId,
      type: type,
      createdAt: now,
      updatedAt: now,
    );

    await transactionRepo.insertTransaction(transaction);
    await userRepo.updateUserBalanceAfterTransaction(amount: amount, transactionType: type);
    await WidgetService.updateWidgetData();

    final formattedAmount = CurrencyFormatter.formatAmount(amount);
    await _showSnackBar('Đã thêm $formattedAmount cho "$description"');
  } catch (e) {
    debugPrint('❌ Quick add from widget failed: $e');
    await _showSnackBar('Không thể thêm giao dịch nhanh: $e', isError: true);
  }
}

Future<void> _showSnackBar(String message, {bool isError = false}) async {
  final navigator = await _waitForNavigator();
  if (navigator == null) return;

  final context = navigator.context;
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

Future<NavigatorState?> _waitForNavigator() async {
  const int maxAttempts = 80;
  int attempt = 0;
  while (rootNavigatorKey.currentState == null && attempt < maxAttempts) {
    await Future.delayed(const Duration(milliseconds: 100));
    attempt++;
  }
  return rootNavigatorKey.currentState;
}

Future<NavigatorState?> _resetNavigatorToRoot() async {
  final navigator = await _waitForNavigator();
  navigator?.popUntil((route) => route.isFirst);
  return navigator;
}
